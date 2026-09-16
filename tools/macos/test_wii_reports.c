#include "wii_reports.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
int main(void) {
    WiiCalibration cal = wii_default_calibration();
    WiiSample sample;
    uint8_t buttons[] = {0x30,0x08,0x01};
    assert(wii_decode(buttons,3,&cal,&sample) && sample.buttons==0x0801 && !sample.motion);
    uint8_t level[] = {0x31,0x00,0x00,128,128,153};
    assert(wii_decode(level,6,&cal,&sample) && sample.motion && sample.buttons==0);
    assert(sample.acceleration[0]==0 && sample.acceleration[1]==0 && sample.acceleration[2]==1);
    uint8_t lsb[] = {0x31,0x60,0x60,128,128,153};
    assert(wii_decode(lsb,6,&cal,&sample) && sample.buttons==0);
    assert(fabs(sample.acceleration[0]-.03)<1e-6 && fabs(sample.acceleration[1]-.02)<1e-6 && fabs(sample.acceleration[2]-1.02)<1e-6);
    for(size_t length=0;length<6;length++) assert(!wii_decode(level,length,&cal,&sample));
    level[0]=0x21; assert(!wii_decode(level,6,&cal,&sample));
    // Published WiiBrew EEPROM example, including low bits and checksum.
    uint8_t factory[] = {0x82,0x82,0x82,0x15,0x9c,0x9c,0x9e,0x38,0x40,0x3e};
    assert(wii_read_calibration(factory,10,&cal) && cal.factory);
    assert(cal.zero[0]==521 && cal.one[0]==627 && cal.one[2]==632);
    factory[9]^=1; assert(!wii_read_calibration(factory,10,&cal));
    assert(!wii_read_calibration(factory,9,&cal));
    uint8_t empty[10]={0}; empty[9]=0x55;
    assert(!wii_read_calibration(empty,10,&cal));
    puts("Wii report decoding checks passed (synthetic packets).");
    return 0;
}
