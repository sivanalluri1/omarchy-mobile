/* Report DRM enumeration errors without modifying devices or udev state. */
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <libudev.h>
int main(void)
{
    struct udev *u=udev_new();
    if(!u){perror("udev_new");return 1;}
    struct udev_enumerate *e=udev_enumerate_new(u);
    if(!e){perror("udev_enumerate_new");udev_unref(u);return 1;}
    udev_enumerate_add_match_subsystem(e,"drm");
    udev_enumerate_add_match_property(e,"DEVTYPE","drm_minor");
    udev_enumerate_add_match_sysname(e,"card[0-9]*");
    errno=0;
    int result=udev_enumerate_scan_devices(e);
    printf("UDEV_SCAN result=%d error=%s errno=%d\n",result,
           result<0?strerror(-result):"success",errno);
    unsigned cards=0;
    if(result==0){
        struct udev_list_entry *entry;
        udev_list_entry_foreach(entry,udev_enumerate_get_list_entry(e)){
            struct udev_device *d=udev_device_new_from_syspath(u,udev_list_entry_get_name(entry));
            if(!d)continue;
            const char *node=udev_device_get_devnode(d);
            if(node){printf("UDEV_CARD %s\n",node);cards++;}
            udev_device_unref(d);
        }
    }
    udev_enumerate_unref(e);udev_unref(u);
    return result==0 && cards>0 ? 0 : 1;
}
