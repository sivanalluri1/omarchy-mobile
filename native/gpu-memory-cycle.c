/* Hardware regression for allocation DMA-BUF descriptor ownership. */
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <vulkan/vulkan.h>
#define CHECK(call) do { VkResult result=(call); if(result!=VK_SUCCESS) { fprintf(stderr,"%s failed: %d\n",#call,result);exit(2); } } while(0)
static unsigned fd_count(void) {
  DIR *dir=opendir("/proc/self/fd");
  if(!dir)exit(2);
  unsigned count=0;struct dirent *entry;
  while((entry=readdir(dir)))if(entry->d_name[0]!='.')count++;
  closedir(dir);return count;
}
static void cycle(VkDevice device,VkPhysicalDevice physical) {
  VkExternalMemoryBufferCreateInfo external={
    .sType=VK_STRUCTURE_TYPE_EXTERNAL_MEMORY_BUFFER_CREATE_INFO,
    .handleTypes=VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT};
  VkBufferCreateInfo info={.sType=VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,.pNext=&external,
    .size=65536,.usage=VK_BUFFER_USAGE_TRANSFER_SRC_BIT|VK_BUFFER_USAGE_TRANSFER_DST_BIT,
    .sharingMode=VK_SHARING_MODE_EXCLUSIVE};
  VkBuffer buffer;CHECK(vkCreateBuffer(device,&info,NULL,&buffer));
  VkMemoryRequirements requirements;vkGetBufferMemoryRequirements(device,buffer,&requirements);
  VkPhysicalDeviceMemoryProperties properties;vkGetPhysicalDeviceMemoryProperties(physical,&properties);
  unsigned type;
  for(type=0;type<properties.memoryTypeCount;type++)if(requirements.memoryTypeBits&(1u<<type))break;
  if(type==properties.memoryTypeCount)exit(2);
  VkExportMemoryAllocateInfo export={.sType=VK_STRUCTURE_TYPE_EXPORT_MEMORY_ALLOCATE_INFO,
    .handleTypes=VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT};
  VkMemoryAllocateInfo alloc={.sType=VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,.pNext=&export,
    .allocationSize=requirements.size,.memoryTypeIndex=type};
  VkDeviceMemory memory;CHECK(vkAllocateMemory(device,&alloc,NULL,&memory));
  CHECK(vkBindBufferMemory(device,buffer,memory,0));
  vkDestroyBuffer(device,buffer,NULL);vkFreeMemory(device,memory,NULL);
}
int main(void) {
  VkApplicationInfo application={.sType=VK_STRUCTURE_TYPE_APPLICATION_INFO,
    .pApplicationName="p613-memory-cycle",.apiVersion=VK_API_VERSION_1_1};
  VkInstanceCreateInfo instance_info={.sType=VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,.pApplicationInfo=&application};
  VkInstance instance;CHECK(vkCreateInstance(&instance_info,NULL,&instance));
  uint32_t count=0;CHECK(vkEnumeratePhysicalDevices(instance,&count,NULL));
  if(count!=1)return 2;
  VkPhysicalDevice physical;CHECK(vkEnumeratePhysicalDevices(instance,&count,&physical));
  VkPhysicalDeviceProperties properties;vkGetPhysicalDeviceProperties(physical,&properties);
  printf("GPU_MEMORY_DEVICE name=%s vendor=%x device=%x\n",properties.deviceName,properties.vendorID,properties.deviceID);
  if(properties.vendorID!=0x5143 || properties.deviceID!=0x06010800)return 2;
  vkGetPhysicalDeviceQueueFamilyProperties(physical,&count,NULL);
  VkQueueFamilyProperties *queues=calloc(count,sizeof(*queues));
  if(!queues)return 2;
  vkGetPhysicalDeviceQueueFamilyProperties(physical,&count,queues);
  uint32_t family;for(family=0;family<count;family++)if(queues[family].queueFlags&VK_QUEUE_GRAPHICS_BIT)break;
  free(queues);if(family==count)return 2;
  float priority=1;
  VkDeviceQueueCreateInfo queue={.sType=VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
    .queueFamilyIndex=family,.queueCount=1,.pQueuePriorities=&priority};
  const char *extensions[]={VK_KHR_EXTERNAL_MEMORY_FD_EXTENSION_NAME,VK_EXT_EXTERNAL_MEMORY_DMA_BUF_EXTENSION_NAME};
  VkDeviceCreateInfo device_info={.sType=VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
    .queueCreateInfoCount=1,.pQueueCreateInfos=&queue,.enabledExtensionCount=2,.ppEnabledExtensionNames=extensions};
  VkDevice device;CHECK(vkCreateDevice(physical,&device_info,NULL,&device));
  for(unsigned i=0;i<8;i++)cycle(device,physical);
  unsigned before=fd_count();
  for(unsigned i=0;i<64;i++)cycle(device,physical);
  CHECK(vkDeviceWaitIdle(device));
  unsigned after=fd_count();
  printf("GPU_MEMORY_CYCLES count=64 fd_before=%u fd_after=%u delta=%d\n",before,after,(int)after-(int)before);
  vkDestroyDevice(device,NULL);vkDestroyInstance(instance,NULL);
  if(after!=before){puts("GPU_MEMORY_FD_LEAK");return 1;}
  puts("GPU_MEMORY_CYCLE_PASS");return 0;
}
