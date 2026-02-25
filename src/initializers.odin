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
