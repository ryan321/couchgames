#include "wii_speaker.h"
#include <assert.h>
#include <stdio.h>
int main(void) {
    WiiSpeaker s={0}; uint8_t out[22], pcm[43];
    for(int i=0;i<43;i++) pcm[i]=(uint8_t)(i+1);
    assert(!wii_speaker_start(&s,pcm,0,0));
    assert(!wii_speaker_start(&s,pcm,WII_SPEAKER_MAX_AUDIO+1,0));
    assert(wii_speaker_start(&s,pcm,43,0));
    double now=0;
    const uint8_t commands[]={0x14,0x19,0x16,0x16,0x16,0x16,0x19};
    for(int i=0;i<7;i++) {
        assert(wii_speaker_tick(&s,now,out)>0 && out[0]==commands[i]);
        assert((out[1]&1)==0); // Speaker commands must not start rumble.
        if(i==2) assert(out[1]==4 && out[2]==0xa2 && out[4]==9 && out[6]==1);
        if(i==4) assert(out[5]==7 && out[7]==0 && out[8]==0xdc && out[9]==0x05);
        assert(wii_speaker_tick(&s,now+.001,out)==0);
        now+=.021;
    }
    now=s.next;
    for(int i=0;i<3;i++) {
        assert(wii_speaker_tick(&s,now,out)==22 && out[0]==0x18);
        size_t count=i==2?3:20;
        assert(out[1]==count*8 && !memcmp(out+2,pcm+i*20,count));
        for(size_t j=2+count;j<22;j++) assert(out[j]==0);
        now=s.next;
    }
    assert(wii_speaker_tick(&s,now,out)==2 && out[0]==0x19 && out[1]==4);
    now+=.021;
    assert(wii_speaker_tick(&s,now,out)==2 && out[0]==0x14 && out[1]==0 && !s.active);
    assert(wii_speaker_tick(&s,now+10,out)==0);
    wii_speaker_start(&s,pcm,43,now);
    wii_speaker_stop(&s,now); // Cancellation always mutes/disables, even mid-initialization.
    assert(wii_speaker_tick(&s,now,out)==2 && out[0]==0x19);
    wii_speaker_start(&s,pcm+20,3,now); // New selection replaces old queued data.
    assert(s.length==3 && s.offset==0 && s.audio[0]==21 && s.stage==0);
    // Small late arrivals must not stretch the stream by an extra timer period.
    wii_speaker_start(&s,pcm,43,0); s.stage=7; s.next=1.0;
    wii_speaker_tick(&s,1.001,out);
    assert(s.next>1.0099 && s.next<1.0101);
    wii_speaker_tick(&s,1.011,out);
    assert(s.next>1.0199 && s.next<1.0201);
    puts("Wii speaker packet checks passed: initialization, ADPCM framing/timing, stop, replacement, limits; no hardware.");
}
