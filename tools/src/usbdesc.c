#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>

static void hexdump(const uint8_t *b, int n) { for (int i = 0; i < n; i++) printf("%02x%s", b[i], i + 1 < n ? " " : ""); }

static const char *uac2ctl(uint32_t bm, int bit) {
    uint32_t v = (bm >> bit) & 3;
    return v == 0 ? "none" : v == 1 ? "read-only" : v == 3 ? "READ/WRITE" : "?";
}

static void parse_config(const uint8_t *bytes, int total, int ci, const IOUSBConfigurationDescriptor *cd) {
    printf("\n### Configuration index %d: bConfigurationValue=%d wTotalLength=%d bNumInterfaces=%d bmAttributes=0x%02x maxPower=%dmA\n",
           ci, cd->bConfigurationValue, total, cd->bNumInterfaces, cd->bmAttributes, cd->MaxPower * 2);
    int off = 0; uint8_t icls = 0, isub = 0, iproto = 0; int uac = 0;
    while (off + 2 <= total) {
        int len = bytes[off]; uint8_t type = bytes[off + 1];
        if (len < 2 || off + len > total) break;
        const uint8_t *b = bytes + off;
        switch (type) {
        case 0x04:
            icls = b[5]; isub = b[6]; iproto = b[7];
            printf("  INTERFACE #%d alt %d endpoints=%d class=%d sub=%d proto=0x%02x", b[2], b[3], b[4], icls, isub, iproto);
            if (icls == 1) {
                printf("  [%s", isub == 1 ? "AudioControl" : isub == 2 ? "AudioStreaming" : isub == 3 ? "MIDIStreaming" : "audio?");
                if (isub == 1) { uac = iproto == 0x20 ? 2 : iproto == 0x30 ? 3 : 1; printf(" UAC%d", uac); }
                printf("]");
            } else if (icls == 3) printf("  [HID]");
            else if (icls == 0xFE) printf("  [DFU / app-specific]");
            printf("\n");
            break;
        case 0x0B:
            printf("  IAD firstIface=%d count=%d class=%d sub=%d proto=0x%02x\n", b[2], b[3], b[4], b[5], b[6]);
            break;
        case 0x05:
            printf("    ENDPOINT 0x%02x attr=0x%02x maxPacket=%d interval=%d\n", b[2], b[3], b[4] | b[5] << 8, b[6]);
            break;
        case 0x24:
            if (icls == 1 && isub == 1) {
                uint8_t sub = b[2];
                if (sub == 0x01) {
                    if (uac == 2) printf("    AC HEADER bcdADC=%02x%02x category=%d bmControls=0x%02x\n", b[4], b[3], b[5], b[8]);
                    else printf("    AC HEADER bcdADC=%02x%02x totalLen=%d\n", b[4], b[3], b[5] | b[6] << 8);
                } else if (sub == 0x02) {
                    int tt = b[4] | b[5] << 8;
                    printf("    INPUT_TERMINAL id=%d type=0x%04x%s", b[3], tt, tt == 0x0101 ? " (USB streaming)" : tt == 0x0201 ? " (microphone)" : "");
                    if (uac == 2) printf(" clock=%d nChannels=%d bmControls=%02x %02x", b[7], b[8], b[13], b[14]); else printf(" nChannels=%d", b[7]);
                    printf("\n");
                } else if (sub == 0x03) {
                    int tt = b[4] | b[5] << 8;
                    printf("    OUTPUT_TERMINAL id=%d type=0x%04x%s sourceId=%d", b[3], tt, tt == 0x0302 ? " (headphones)" : tt == 0x0301 ? " (speaker)" : tt == 0x0101 ? " (USB streaming)" : tt == 0x0602 ? " (digital out)" : "", b[7]);
                    if (uac == 2) printf(" clock=%d bmControls=%02x %02x", b[8], b[9], b[10]);
                    printf("\n");
                } else if (sub == 0x06) {
                    if (uac == 2) {
                        int n = (len - 6) / 4;
                        printf("    FEATURE_UNIT id=%d source=%d  <-- volume lives here (UAC2 bmaControls)\n", b[3], b[4]);
                        for (int ch = 0; ch < n; ch++) {
                            const uint8_t *p = b + 5 + ch * 4;
                            uint32_t bm = p[0] | p[1] << 8 | p[2] << 16 | p[3] << 24;
                            printf("      ch%d (%s): mute=%s  VOLUME=%s  bass=%s treble=%s autoGain=%s  raw=0x%08x\n", ch, ch == 0 ? "master" : "channel",
                                   uac2ctl(bm, 0), uac2ctl(bm, 2), uac2ctl(bm, 4), uac2ctl(bm, 8), uac2ctl(bm, 12), bm);
                        }
                    } else {
                        int cs = b[5]; if (cs < 1) cs = 1; int n = (len - 7) / cs;
                        printf("    FEATURE_UNIT id=%d source=%d bControlSize=%d  <-- volume lives here (UAC1 bmaControls)\n", b[3], b[4], cs);
                        for (int ch = 0; ch < n; ch++) {
                            uint32_t bm = 0; for (int k = 0; k < cs; k++) bm |= b[6 + ch * cs + k] << (8 * k);
                            printf("      ch%d (%s): mute=%s  VOLUME=%s  bass=%s treble=%s autoGain=%s  raw=0x%x\n", ch, ch == 0 ? "master" : "channel",
                                   bm & 1 ? "YES" : "no", bm & 2 ? "YES" : "no", bm & 4 ? "YES" : "no", bm & 16 ? "YES" : "no", bm & 64 ? "YES" : "no", bm);
                        }
                    }
                } else if (sub == 0x0A && uac == 2) {
                    printf("    CLOCK_SOURCE id=%d bmAttributes=0x%02x bmControls=0x%02x\n", b[3], b[4], b[5]);
                } else if (sub == 0x0B && uac == 2) {
                    printf("    CLOCK_SELECTOR id=%d nInputs=%d\n", b[3], b[4]);
                } else if (sub == 0x05) {
                    printf("    SELECTOR_UNIT id=%d nInputs=%d\n", b[3], b[4]);
                } else if (sub == 0x04) {
                    printf("    MIXER_UNIT id=%d\n", b[3]);
                } else {
                    printf("    AC CS subtype=0x%02x raw=", sub); hexdump(b, len); printf("\n");
                }
            } else if (icls == 1 && isub == 2) {
                uint8_t sub = b[2];
                if (sub == 0x01) {
                    if (uac == 2) printf("    AS GENERAL terminal=%d bmControls=0x%02x formatType=%d formats=0x%08x nChannels=%d\n", b[3], b[4], b[5], b[6] | b[7] << 8 | b[8] << 16 | b[9] << 24, b[10]);
                    else printf("    AS GENERAL terminal=%d delay=%d formatTag=0x%04x\n", b[3], b[4], b[5] | b[6] << 8);
                } else if (sub == 0x02) {
                    if (uac == 2) printf("    AS FORMAT_TYPE type=%d subslot=%d bitRes=%d\n", b[3], b[4], b[5]);
                    else {
                        int nf = b[7];
                        printf("    AS FORMAT_TYPE type=%d nChannels=%d subframe=%d bitRes=%d rates=", b[3], b[4], b[5], b[6]);
                        if (nf == 0) printf("continuous");
                        for (int i = 0; i < nf; i++) { const uint8_t *p = b + 8 + i * 3; printf("%s%d", i ? "," : "", p[0] | p[1] << 8 | p[2] << 16); }
                        printf("\n");
                    }
                } else { printf("    AS CS subtype=0x%02x raw=", sub); hexdump(b, len); printf("\n"); }
            } else { printf("    CS_INTERFACE raw="); hexdump(b, len); printf("\n"); }
            break;
        case 0x25: printf("    CS_ENDPOINT raw="); hexdump(b, len); printf("\n"); break;
        case 0x21: printf("    HID descriptor raw="); hexdump(b, len); printf("\n"); break;
        case 0x02: break; // config descriptor header itself
        default: printf("  desc type=0x%02x len=%d raw=", type, len); hexdump(b, len); printf("\n");
        }
        off += len;
    }
}

int main(void) {
    // IOKit USB matching rejects a bare idVendor key, so enumerate every IOUSBHostDevice and filter by vendor ourselves.
    io_iterator_t it = 0;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOUSBHostDevice"), &it) != KERN_SUCCESS) { printf("match failed\n"); return 1; }
    io_service_t svc = 0, cand;
    while ((cand = IOIteratorNext(it))) {
        CFNumberRef v = IORegistryEntryCreateCFProperty(cand, CFSTR("idVendor"), kCFAllocatorDefault, 0);
        int vid = 0; if (v) { CFNumberGetValue(v, kCFNumberIntType, &vid); CFRelease(v); }
        if (vid == 10610) { svc = cand; break; }
        IOObjectRelease(cand);
    }
    if (!svc) { printf("FiiO not found\n"); return 1; }
    IOCFPlugInInterface **plug = NULL; SInt32 score = 0;
    kern_return_t kr = IOCreatePlugInInterfaceForService(svc, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plug, &score);
    if (kr != KERN_SUCCESS || !plug) { printf("plugin failed 0x%x\n", kr); return 1; }
    IOUSBDeviceInterface **dev = NULL;
    (*plug)->QueryInterface(plug, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID *)&dev);
    if (!dev) { printf("QueryInterface failed\n"); return 1; }
    UInt8 n = 0, cur = 0; (*dev)->GetNumberOfConfigurations(dev, &n); (*dev)->GetConfiguration(dev, &cur);
    UInt16 vendor = 0, product = 0, rel = 0; (*dev)->GetDeviceVendor(dev, &vendor); (*dev)->GetDeviceProduct(dev, &product); (*dev)->GetDeviceReleaseNumber(dev, &rel);
    printf("device %04x:%04x bcdDevice=%04x  configurations=%d  current bConfigurationValue=%d\n", vendor, product, rel, n, cur);
    for (UInt8 i = 0; i < n; i++) {
        IOUSBConfigurationDescriptorPtr cd = NULL;
        if ((*dev)->GetConfigurationDescriptorPtr(dev, i, &cd) != KERN_SUCCESS || !cd) { printf("config %d: no descriptor\n", i); continue; }
        parse_config((const uint8_t *)cd, USBToHostWord(cd->wTotalLength), i, cd);
    }
    return 0;
}
