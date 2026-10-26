#include <stdio.h>
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
int main(void) {
    io_iterator_t it = 0;
    IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOUSBHostDevice"), &it);
    io_service_t svc = 0, cand;
    while ((cand = IOIteratorNext(it))) {
        CFNumberRef v = IORegistryEntryCreateCFProperty(cand, CFSTR("idVendor"), kCFAllocatorDefault, 0);
        int vid = 0; if (v) { CFNumberGetValue(v, kCFNumberIntType, &vid); CFRelease(v); }
        if (vid == 10610) { svc = cand; break; }
        IOObjectRelease(cand);
    }
    if (!svc) { printf("FiiO not found\n"); return 1; }
    IOCFPlugInInterface **plug = NULL; SInt32 score = 0;
    if (IOCreatePlugInInterfaceForService(svc, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plug, &score) != KERN_SUCCESS) { printf("plugin failed\n"); return 1; }
    IOUSBDeviceInterface **dev = NULL;
    (*plug)->QueryInterface(plug, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID *)&dev);
    kern_return_t kr = (*dev)->USBDeviceOpen(dev);
    if (kr != KERN_SUCCESS) { printf("USBDeviceOpen failed 0x%x, trying seize\n", kr); kr = (*dev)->USBDeviceOpenSeize(dev); }
    if (kr != KERN_SUCCESS) { printf("open failed 0x%x (%s)\n", kr, kr == kIOReturnExclusiveAccess ? "exclusive access held by driver" : "other"); return 1; }
    kr = (*dev)->USBDeviceReEnumerate(dev, 0);
    printf("USBDeviceReEnumerate -> 0x%x %s\n", kr, kr == KERN_SUCCESS ? "(ok, device resetting)" : "(failed)");
    (*dev)->USBDeviceClose(dev);
    return kr == KERN_SUCCESS ? 0 : 1;
}
