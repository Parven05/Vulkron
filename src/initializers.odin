package vulkron

import vk "vendor:vulkan"

command_pool_create_info :: proc(
	queueFamilyIndex: u32,
	flags: vk.CommandPoolCreateFlags = {},
) -> vk.CommandPoolCreateInfo {
	info := vk.CommandPoolCreateInfo {
		sType            = .COMMAND_POOL_CREATE_INFO,
		queueFamilyIndex = queueFamilyIndex,
		flags            = flags,
	}
	return info
}

command_buffer_allocate_info :: proc(
	pool: vk.CommandPool,
	count: u32 = 1,
) -> vk.CommandBufferAllocateInfo {
	info := vk.CommandBufferAllocateInfo {
		sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
		commandPool        = pool,
		commandBufferCount = count,
		level              = .PRIMARY,
	}
	return info
}

fence_create_info :: proc(flags: vk.FenceCreateFlags = {}) -> vk.FenceCreateInfo {
	info := vk.FenceCreateInfo {
		sType = .FENCE_CREATE_INFO,
		flags = flags,
	}
	return info
}

semaphore_create_info :: proc(flags: vk.SemaphoreCreateFlags = {}) -> vk.SemaphoreCreateInfo {
	info := vk.SemaphoreCreateInfo {
		sType = .SEMAPHORE_CREATE_INFO,
		flags = flags,
	}
	return info
}

command_buffer_begin_info :: proc(
	flags: vk.CommandBufferUsageFlags = {},
) -> vk.CommandBufferBeginInfo {
	info := vk.CommandBufferBeginInfo {
		sType = .COMMAND_BUFFER_BEGIN_INFO,
		flags = flags,
	}
	return info
}

semaphore_submit_info :: proc(
	stageMask: vk.PipelineStageFlags2,
	semaphore: vk.Semaphore,
) -> vk.SemaphoreSubmitInfo {
	submitInfo := vk.SemaphoreSubmitInfo {
		sType     = .SEMAPHORE_SUBMIT_INFO,
		semaphore = semaphore,
		stageMask = stageMask,
		value     = 1,
	}
	return submitInfo
}

command_buffer_submit_info :: proc(cmd: vk.CommandBuffer) -> vk.CommandBufferSubmitInfo {
	info := vk.CommandBufferSubmitInfo {
		sType         = .COMMAND_BUFFER_SUBMIT_INFO,
		commandBuffer = cmd,
	}
	return info
}

submit_info :: proc(
	cmd: ^vk.CommandBufferSubmitInfo,
	signalSemaphoreInfo: ^vk.SemaphoreSubmitInfo,
	waitSemaphoreInfo: ^vk.SemaphoreSubmitInfo,
) -> vk.SubmitInfo2 {
	info := vk.SubmitInfo2 {
		sType                    = .SUBMIT_INFO_2,
		waitSemaphoreInfoCount   = waitSemaphoreInfo == nil ? 0 : 1,
		pWaitSemaphoreInfos      = waitSemaphoreInfo,
		signalSemaphoreInfoCount = signalSemaphoreInfo == nil ? 0 : 1,
		pSignalSemaphoreInfos    = signalSemaphoreInfo,
		commandBufferInfoCount   = 1,
		pCommandBufferInfos      = cmd,
	}
	return info
}

image_subresource_range :: proc(aspectMask: vk.ImageAspectFlags) -> vk.ImageSubresourceRange {
	subImage := vk.ImageSubresourceRange {
		aspectMask = aspectMask,
		levelCount = vk.REMAINING_MIP_LEVELS,
		layerCount = vk.REMAINING_ARRAY_LAYERS,
	}
	return subImage
}
