"""Source-library supervision tests; fake children never launch hardware helpers."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from library import GAMES, LibraryHost, startup_status, startup_ready, publish_foreground
from game_catalog import rendering_arguments
from godot_tools import resolve_godot

class Process:
    def __init__(self):
        self.returncode = None
        self.terminated = False
    def poll(self): return self.returncode
    def terminate(self):
        self.terminated = True
        self.returncode = -15
    def wait(self, timeout=None): return self.returncode

class HostTests(unittest.TestCase):
    def test_game_specific_renderer_and_explicit_fallback(self):
        with patch('sys.platform', 'darwin'):
            self.assertEqual(rendering_arguments('gauntlet'),
                             ['--rendering-method', 'forward_plus', '--rendering-driver', 'metal'])
            self.assertEqual(rendering_arguments('gauntlet', compatibility=True), [])
            self.assertEqual(rendering_arguments('sunbreak'),
                             ['--rendering-method', 'forward_plus', '--rendering-driver', 'metal'])
            self.assertEqual(rendering_arguments('sunbreak', compatibility=True), [])
            for game_id in GAMES:
                if GAMES[game_id].get('renderer') != 'forward_plus':
                    self.assertEqual(rendering_arguments(game_id), [])
        with patch('sys.platform', 'win32'):
            self.assertEqual(rendering_arguments('gauntlet'), ['--rendering-method', 'forward_plus'])
    @patch.dict('os.environ', {'COUCH_CLI': '/local app/Contents/Resources/couch'})
    @patch('godot_tools.subprocess.run')
    def test_player_app_uses_bundled_doctor_without_cargo(self, run):
        run.return_value.returncode = 0
        run.return_value.stdout = json.dumps({'data': {'godot': {'executable': '/installed/Godot'}}})
        self.assertEqual(resolve_godot('/custom/Godot.app'), '/installed/Godot')
        self.assertEqual(run.call_args.args[0], ['/local app/Contents/Resources/couch', '--json', '--godot', '/custom/Godot.app', 'doctor', '--require-godot'])

    def test_startup_does_not_report_ready_before_renderer_signal(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'status.json'
            with patch.dict('os.environ', {'COUCH_PLAYER_STARTUP': str(path)}):
                for phase in ('checking', 'importing', 'opening'):
                    startup_status(phase)
                    self.assertEqual(json.loads(path.read_text())['phase'], phase)
                    self.assertFalse(startup_ready(path))
                path.write_text('{"phase":"ready"}')
                self.assertTrue(startup_ready(path))
                path.write_text('{incomplete')
                self.assertFalse(startup_ready(path))
                path.unlink()
                self.assertFalse(startup_ready(path))

    def test_reopen_tracks_library_then_game_then_library(self):
        with tempfile.TemporaryDirectory() as directory:
            startup = Path(directory) / 'status.json'
            for game_pid, expected in [(None, 101), (202, 202), (None, 101)]:
                publish_foreground(startup, 101, game_pid)
                self.assertEqual(json.loads((startup.parent / 'foreground.json').read_text()), {'pid': expected, 'library_pid': 101})

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.calls = []
        def popen(command, **kwargs):
            process = Process()
            self.calls.append((command, kwargs, process))
            return process
        self.host = LibraryHost('/existing/Godot', self.directory.name, popen=popen,
                                reader_builder=lambda fleet: '/reader/fleet' if fleet else '/reader/single')
    def tearDown(self):
        self.host.cleanup()
        self.directory.cleanup()
    def request(self, **request):
        Path(self.directory.name,'request.json').write_text(json.dumps(request))
        self.host.tick()
    def test_every_game_uses_same_engine_and_exact_scene(self):
        for game_id, game in GAMES.items():
            self.request(action='launch',game=game_id,request_id=game_id)
            self.assertEqual(self.host.state['phase'],'running')
            self.assertEqual(self.host.state['request_id'],game_id)
            self.assertEqual(self.calls[-1][0][0],'/existing/Godot')
            self.assertEqual(self.calls[-1][0][-1],game['scene'])
            self.host.game.returncode = 0
            self.host.tick()
            self.assertEqual(self.host.state['phase'],'idle')
    def test_duplicate_launch_and_crash_recovery(self):
        self.request(action='launch',game='cloudbound')
        self.request(action='launch',game='pocket-rally')
        self.assertEqual(len(self.calls),1)
        self.host.game.returncode = 1
        self.host.tick()
        self.assertEqual(self.host.state['phase'],'error')
        self.request(action='launch',game='pocket-rally')
        self.assertEqual(len(self.calls),2)
    @patch('library.sys.platform','darwin')
    def test_native_reader_selection_and_cleanup(self):
        for game_id, reader in [('cloudbound','single'),('pocket-rally','fleet'),('gauntlet','fleet')]:
            self.request(action='launch',game=game_id,input='native-wii')
            self.assertEqual(self.calls[-2][0][0],'/reader/'+reader)
            snapshot_dir = self.host.wii_session.name
            helper = self.host.helper
            self.host.game.returncode = 0
            self.host.tick()
            self.assertTrue(helper.terminated)
            self.assertFalse(Path(snapshot_dir).exists())
    def test_bad_request_never_executes(self):
        for game in ['../../oops',[],None]:
            self.request(action='launch',game=game)
            self.assertEqual(self.host.state['phase'],'error')
        self.assertFalse(self.calls)
    @patch('library.sys.platform','darwin')
    def test_failed_game_spawn_stops_helper(self):
        original = self.host.popen
        def failing(command, **kwargs):
            if command[0]=='/existing/Godot': raise OSError('Cannot start engine')
            return original(command, **kwargs)
        self.host.popen = failing
        self.request(action='launch',game='pocket-rally',input='native-wii')
        self.assertEqual(self.host.state['phase'],'error')
        self.assertTrue(self.calls[0][2].terminated)
        self.assertIsNone(self.host.wii_session)
    def test_stop_only_owned_game(self):
        self.request(action='launch',game='little-world')
        game = self.host.game
        self.request(action='stop')
        self.assertTrue(game.terminated)
        self.assertEqual(self.host.state['phase'],'idle')
    @patch.dict('os.environ',{'COUCH_WII_NATIVE_STATE':'/old','COUCH_WII_FLEET_DIR':'/old','COUCH_XPAD_NATIVE_STATE':'/old','COUCH_LIBRARY_SESSION':'/host','COUCH_PLAYER_STARTUP':'/private/startup.json'})
    def test_child_does_not_inherit_another_session(self):
        self.request(action='launch',game='cloudbound')
        environment = self.calls[-1][1]['env']
        for name in ['COUCH_WII_NATIVE_STATE','COUCH_WII_FLEET_DIR','COUCH_XPAD_NATIVE_STATE','COUCH_LIBRARY_SESSION','COUCH_PLAYER_STARTUP']:
            self.assertFalse(name in environment, name + " must not reach the game")
    def test_xpad_helper_when_pad_present(self):
        self.host.xpad_builder = lambda: '/xpad/reader'
        self.host.xpad_available = lambda: True
        self.request(action='launch', game='little-world')
        self.assertEqual(self.calls[0][0][0], '/xpad/reader')
        self.assertEqual(self.calls[-1][0][0], '/existing/Godot')
        environment = self.calls[-1][1]['env']
        self.assertTrue(environment['COUCH_XPAD_NATIVE_STATE'].endswith('state.json'))
        helper = self.host.xpad_helper
        self.host.game.returncode = 0
        self.host.tick()
        self.assertTrue(helper.terminated)

if __name__=='__main__': unittest.main()
