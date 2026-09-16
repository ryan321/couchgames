// Original bounded speaker transport using https://wiibrew.org/wiki/Wiimote#Speaker
#ifndef COUCH_WII_SPEAKER_H
#define COUCH_WII_SPEAKER_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#define WII_SPEAKER_MAX_AUDIO 1600
// Yamaha ADPCM at 4000 Hz: 40 samples per 10 ms report, at modest speaker volume.
typedef struct {
    uint8_t audio[WII_SPEAKER_MAX_AUDIO];
    size_t length, offset;
    unsigned stage;
    double next;
    bool active;
} WiiSpeaker;
static inline bool wii_speaker_start(WiiSpeaker *s, const uint8_t *audio, size_t length, double now) {
    if (!audio || !length || length>WII_SPEAKER_MAX_AUDIO) return false;
    memcpy(s->audio,audio,length); s->length=length; s->offset=0;
    s->stage=0; s->next=now; s->active=true;
    return true;
}
static inline void wii_speaker_stop(WiiSpeaker *s, double now) {
    s->stage=8; s->next=now; s->active=true;
}
static inline size_t wii_speaker_register(uint8_t out[22], uint8_t address, const uint8_t *bytes, size_t count) {
    memset(out,0,22); out[0]=0x16; out[1]=0x04; out[2]=0xa2; out[4]=address;
    out[5]=(uint8_t)count; memcpy(out+6,bytes,count); return 22;
}
// At most one packet per tick. Never burst old packets after a scheduling delay.
static inline size_t wii_speaker_tick(WiiSpeaker *s, double now, uint8_t out[22]) {
    if (!s->active || now<s->next) return 0;
    memset(out,0,22);
    const uint8_t one=1, eight=8;
    const uint8_t config[7]={0,0,0xdc,0x05,0x20,0,0};
    size_t count=2;
    switch (s->stage) {
        case 0: out[0]=0x14; out[1]=4; break;
        case 1: out[0]=0x19; out[1]=4; break;
        case 2: count=wii_speaker_register(out,9,&one,1); break;
        case 3: count=wii_speaker_register(out,1,&eight,1); break;
        case 4: count=wii_speaker_register(out,1,config,7); break;
        case 5: count=wii_speaker_register(out,8,&one,1); break;
        case 6: out[0]=0x19; out[1]=0; break;
        case 7: {
            size_t n=s->length-s->offset; if(n>20) n=20;
            out[0]=0x18; out[1]=(uint8_t)(n<<3); memcpy(out+2,s->audio+s->offset,n);
            s->offset+=n; s->next+=(double)n/2000.0;
            // Bound recovery after a major stall; never queue an unbounded catch-up burst.
            if(s->next<now-0.020) s->next=now;
            if(s->offset==s->length) s->stage=8;
            return 22;
        }
        case 8: out[0]=0x19; out[1]=4; break;
        default: out[0]=0x14; out[1]=0; s->active=false; return 2;
    }
    s->stage++; s->next=now+0.020;
    return count;
}
#endif
