// WiiBrew's 0x30/0x31 and EEPROM calibration formats. No OS dependencies.
#ifndef COUCH_WII_REPORTS_H
#define COUCH_WII_REPORTS_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct { int zero[3], one[3]; bool factory; } WiiCalibration;
typedef struct { unsigned buttons; bool motion; double acceleration[3]; } WiiSample;

static inline WiiCalibration wii_default_calibration(void) {
    // Approximate fallback (100 counts/g), also used by SDL's Wii driver.
    return (WiiCalibration){{512,512,512},{612,612,612},false};
}

static inline bool wii_read_calibration(const uint8_t *bytes, size_t length, WiiCalibration *out) {
    if (length < 10) return false;
    uint8_t checksum = 0x55;
    for (int i=0; i<9; i++) checksum += bytes[i];
    if (checksum != bytes[9]) return false;
    WiiCalibration next = {.factory=true};
    for (int i=0; i<3; i++) {
        int shift = 4 - 2*i;
        next.zero[i] = (bytes[i]<<2) | ((bytes[3]>>shift)&3);
        next.one[i] = (bytes[i+4]<<2) | ((bytes[7]>>shift)&3);
        int span = next.one[i] - next.zero[i];
        if (span < 40 || span > 200 || next.zero[i] < 256 || next.zero[i] > 768) return false;
    }
    *out = next;
    return true;
}

static inline bool wii_decode(const uint8_t *bytes, size_t length, const WiiCalibration *cal, WiiSample *out) {
    if (length < 3 || (bytes[0] != 0x30 && bytes[0] != 0x31)) return false;
    if (bytes[0] == 0x31 && length < 6) return false;
    *out = (WiiSample){0};
    // Strip accelerometer LSBs from the button word; they are NOT button presses.
    out->buttons = ((bytes[1]<<8) | bytes[2]) & 0x1f9f;
    out->motion = bytes[0] == 0x31;
    if (out->motion) {
        int raw[3] = {(bytes[3]<<2) | ((bytes[1]>>5)&3),
                      (bytes[4]<<2) | ((bytes[2]>>4)&2),
                      (bytes[5]<<2) | ((bytes[2]>>5)&2)};
        for (int i=0; i<3; i++) out->acceleration[i] = (double)(raw[i]-cal->zero[i])/(cal->one[i]-cal->zero[i]);
    }
    return true;
}
#endif
