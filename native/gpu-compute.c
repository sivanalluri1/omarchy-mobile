/* Real Vulkan dispatch/readback; refuses non-Qualcomm and CPU devices. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <vulkan/vulkan.h>
#include "gpu-compute-spv.h"
#define CHECK(call) do { VkResult result_ = (call); if (result_ != VK_SUCCESS) { \
    fprintf(stderr,"%s failed: %d\n",#call,result_); exit(1); } } while (0)
int main(void)
{
    setbuf(stdout,NULL);
    alarm(60);
    VkApplicationInfo app={.sType=VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName="p613-compute-proof",.apiVersion=VK_API_VERSION_1_1};
    VkInstanceCreateInfo ici={.sType=VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,.pApplicationInfo=&app};
    VkInstance instance; CHECK(vkCreateInstance(&ici,NULL,&instance));
    uint32_t count=0; CHECK(vkEnumeratePhysicalDevices(instance,&count,NULL));
    if(!count || count>16) {fprintf(stderr,"Unexpected GPU count: %u\n",count);return 1;}
    VkPhysicalDevice devices[16]; CHECK(vkEnumeratePhysicalDevices(instance,&count,devices));
    VkPhysicalDevice physical=VK_NULL_HANDLE;
    for(uint32_t i=0;i<count;i++) {
        VkPhysicalDeviceProperties p; vkGetPhysicalDeviceProperties(devices[i],&p);
        printf("DEVICE name=%s vendor=%#x device=%#x type=%u api=%u.%u.%u driver=%u\n",
            p.deviceName,p.vendorID,p.deviceID,p.deviceType,VK_VERSION_MAJOR(p.apiVersion),
            VK_VERSION_MINOR(p.apiVersion),VK_VERSION_PATCH(p.apiVersion),p.driverVersion);
        if(p.vendorID==0x5143 && (p.deviceType==VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU ||
            p.deviceType==VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU)) physical=devices[i];
    }
    if(!physical) {fprintf(stderr,"No hardware Qualcomm Vulkan device; refusing fallback\n");return 1;}
    uint32_t queues=0; vkGetPhysicalDeviceQueueFamilyProperties(physical,&queues,NULL);
    VkQueueFamilyProperties *qp=calloc(queues,sizeof(*qp)); if(!qp) return 1;
    vkGetPhysicalDeviceQueueFamilyProperties(physical,&queues,qp);
    uint32_t family=UINT32_MAX;
    for(uint32_t i=0;i<queues;i++) if(qp[i].queueCount && (qp[i].queueFlags&VK_QUEUE_COMPUTE_BIT)) {family=i;break;}
    free(qp); if(family==UINT32_MAX) return 1;
    float priority=1;
    VkDeviceQueueCreateInfo qci={.sType=VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .queueFamilyIndex=family,.queueCount=1,.pQueuePriorities=&priority};
    VkDeviceCreateInfo dci={.sType=VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,.queueCreateInfoCount=1,.pQueueCreateInfos=&qci};
    VkDevice device; CHECK(vkCreateDevice(physical,&dci,NULL,&device));
    VkQueue queue; vkGetDeviceQueue(device,family,0,&queue);
    const VkDeviceSize bytes=1024*sizeof(uint32_t);
    VkBufferCreateInfo bci={.sType=VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,.size=bytes,
        .usage=VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,.sharingMode=VK_SHARING_MODE_EXCLUSIVE};
    VkBuffer buffer; CHECK(vkCreateBuffer(device,&bci,NULL,&buffer));
    VkMemoryRequirements req; vkGetBufferMemoryRequirements(device,buffer,&req);
    VkPhysicalDeviceMemoryProperties mp; vkGetPhysicalDeviceMemoryProperties(physical,&mp);
    uint32_t mt=UINT32_MAX;
    for(uint32_t i=0;i<mp.memoryTypeCount;i++) if((req.memoryTypeBits&(1u<<i)) &&
        (mp.memoryTypes[i].propertyFlags&VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT)) {mt=i;break;}
    if(mt==UINT32_MAX) {fprintf(stderr,"No host-visible memory\n");return 1;}
    VkMemoryAllocateInfo mai={.sType=VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize=req.size,.memoryTypeIndex=mt};
    VkDeviceMemory memory; CHECK(vkAllocateMemory(device,&mai,NULL,&memory));
    CHECK(vkBindBufferMemory(device,buffer,memory,0));
    void *mapped; CHECK(vkMapMemory(device,memory,0,VK_WHOLE_SIZE,0,&mapped));
    memset(mapped,0,bytes);
    VkMappedMemoryRange range={.sType=VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE,.memory=memory,.offset=0,.size=VK_WHOLE_SIZE};
    CHECK(vkFlushMappedMemoryRanges(device,1,&range));
    VkDescriptorSetLayoutBinding binding={.binding=0,.descriptorType=VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
        .descriptorCount=1,.stageFlags=VK_SHADER_STAGE_COMPUTE_BIT};
    VkDescriptorSetLayoutCreateInfo lci={.sType=VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .bindingCount=1,.pBindings=&binding};
    VkDescriptorSetLayout layout; CHECK(vkCreateDescriptorSetLayout(device,&lci,NULL,&layout));
    VkPipelineLayoutCreateInfo plci={.sType=VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount=1,.pSetLayouts=&layout};
    VkPipelineLayout pipeline_layout; CHECK(vkCreatePipelineLayout(device,&plci,NULL,&pipeline_layout));
    VkShaderModuleCreateInfo smci={.sType=VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize=sizeof(compute_spv),.pCode=compute_spv};
    VkShaderModule shader; CHECK(vkCreateShaderModule(device,&smci,NULL,&shader));
    VkComputePipelineCreateInfo pci={.sType=VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
        .stage={.sType=VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage=VK_SHADER_STAGE_COMPUTE_BIT,.module=shader,.pName="main"},.layout=pipeline_layout};
    VkPipeline pipeline; CHECK(vkCreateComputePipelines(device,VK_NULL_HANDLE,1,&pci,NULL,&pipeline));
    VkDescriptorPoolSize pool_size={.type=VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,.descriptorCount=1};
    VkDescriptorPoolCreateInfo dpci={.sType=VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .maxSets=1,.poolSizeCount=1,.pPoolSizes=&pool_size};
    VkDescriptorPool pool; CHECK(vkCreateDescriptorPool(device,&dpci,NULL,&pool));
    VkDescriptorSetAllocateInfo dsai={.sType=VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .descriptorPool=pool,.descriptorSetCount=1,.pSetLayouts=&layout};
    VkDescriptorSet set; CHECK(vkAllocateDescriptorSets(device,&dsai,&set));
    VkDescriptorBufferInfo dbi={.buffer=buffer,.offset=0,.range=bytes};
    VkWriteDescriptorSet write={.sType=VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,.dstSet=set,
        .dstBinding=0,.descriptorCount=1,.descriptorType=VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,.pBufferInfo=&dbi};
    vkUpdateDescriptorSets(device,1,&write,0,NULL);
    VkCommandPoolCreateInfo cpci={.sType=VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,.queueFamilyIndex=family};
    VkCommandPool command_pool; CHECK(vkCreateCommandPool(device,&cpci,NULL,&command_pool));
    VkCommandBufferAllocateInfo cbai={.sType=VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool=command_pool,.level=VK_COMMAND_BUFFER_LEVEL_PRIMARY,.commandBufferCount=1};
    VkCommandBuffer cb; CHECK(vkAllocateCommandBuffers(device,&cbai,&cb));
    VkCommandBufferBeginInfo begin={.sType=VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
    CHECK(vkBeginCommandBuffer(cb,&begin));
    vkCmdBindPipeline(cb,VK_PIPELINE_BIND_POINT_COMPUTE,pipeline);
    vkCmdBindDescriptorSets(cb,VK_PIPELINE_BIND_POINT_COMPUTE,pipeline_layout,0,1,&set,0,NULL);
    vkCmdDispatch(cb,16,1,1);
    VkMemoryBarrier barrier={.sType=VK_STRUCTURE_TYPE_MEMORY_BARRIER,
        .srcAccessMask=VK_ACCESS_SHADER_WRITE_BIT,.dstAccessMask=VK_ACCESS_HOST_READ_BIT};
    vkCmdPipelineBarrier(cb,VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,VK_PIPELINE_STAGE_HOST_BIT,0,1,&barrier,0,NULL,0,NULL);
    CHECK(vkEndCommandBuffer(cb));
    VkFenceCreateInfo fci={.sType=VK_STRUCTURE_TYPE_FENCE_CREATE_INFO};
    VkFence fence; CHECK(vkCreateFence(device,&fci,NULL,&fence));
    VkSubmitInfo submit={.sType=VK_STRUCTURE_TYPE_SUBMIT_INFO,.commandBufferCount=1,.pCommandBuffers=&cb};
    CHECK(vkQueueSubmit(queue,1,&submit,fence));
    CHECK(vkWaitForFences(device,1,&fence,VK_TRUE,10000000000ull));
    CHECK(vkInvalidateMappedMemoryRanges(device,1,&range));
    uint32_t *values=mapped;
    for(uint32_t i=0;i<1024;i++) {
        uint32_t expected=(i*1664525u+1013904223u)^0xa5a55a5au;
        if(values[i]!=expected) {fprintf(stderr,"Mismatch index=%u actual=%#x expected=%#x\n",i,values[i],expected);return 1;}
    }
    printf("GPU_COMPUTE_PASS words=1024 queue_family=%u first=%#x last=%#x\n",family,values[0],values[1023]);
    vkUnmapMemory(device,memory);
    vkDestroyFence(device,fence,NULL); vkDestroyCommandPool(device,command_pool,NULL);
    vkDestroyDescriptorPool(device,pool,NULL); vkDestroyPipeline(device,pipeline,NULL);
    vkDestroyShaderModule(device,shader,NULL); vkDestroyPipelineLayout(device,pipeline_layout,NULL);
    vkDestroyDescriptorSetLayout(device,layout,NULL); vkDestroyBuffer(device,buffer,NULL);
    vkFreeMemory(device,memory,NULL); vkDestroyDevice(device,NULL); vkDestroyInstance(instance,NULL);
    return 0;
}
