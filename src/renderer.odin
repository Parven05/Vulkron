package vulkron

import "core:flags"
import "core:log"
import "core:math"

import "vendor:glfw"
import vk "vendor:vulkan"

import "../libs/vkb"
import "../libs/vma"

// glfw
window: glfw.WindowHandle

// init
// vk-bootstrap
vkb_instance: ^vkb.Instance
vkb_physical_device: ^vkb.Physical_Device
vkb_device: ^vkb.Device
vkb_swapchain: ^vkb.Swapchain

vk_instance: vk.Instance
vk_surface: vk.SurfaceKHR
vk_device: vk.Device
vk_physical_device: vk.PhysicalDevice

// swapchain
vk_swapchain: vk.SwapchainKHR
swapchain_extent: vk.Extent2D
swapchain_format: vk.Format
swapchain_images: []vk.Image
swapchain_image_views: []vk.ImageView

// draw resources
draw_image: Allocated_Image
draw_extent: vk.Extent2D

Frame_Data :: struct {
	// commands
	command_pool:          vk.CommandPool,
	main_command_buffer:   vk.CommandBuffer,
	// synchronization
	swapchain_semaphore:   vk.Semaphore,
	render_semaphore:      vk.Semaphore,
	render_fence:          vk.Fence,
	swapchain_image_index: u32,
}
FRAME_OVERLAP :: 2
frames: [FRAME_OVERLAP]Frame_Data
frame_number: int

// queue
graphics_queue: vk.Queue
graphics_queue_family: u32

// allocator
vma_allocator: vma.Allocator


get_current_frame :: #force_inline proc() -> ^Frame_Data #no_bounds_check {
	return &frames[frame_number % FRAME_OVERLAP]
}

init_glfw_window :: proc() {
	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
	glfw.WindowHint(glfw.RESIZABLE, glfw.FALSE)

	window = glfw.CreateWindow(800, 600, "Vulkron", nil, nil)
	if window == nil {
		log.error("Failed to create GLFW window")
	} else {
		log.info("Window created successfully")
	}
}

start :: proc() {
	create_instance()
	if vkb_instance != nil {
		create_device()
		create_queue()
		create_allocator()
		create_swapchain()
		create_commands()
		init_sync()
	}
}

create_instance :: proc() {
	instance_builder := vkb.create_instance_builder()
	defer vkb.destroy_instance_builder(instance_builder)

	vkb.instance_builder_set_app_name(instance_builder, "Vulkron")
	vkb.instance_builder_require_api_version(instance_builder, vk.API_VERSION_1_3)

	when ODIN_DEBUG {
		vkb.instance_builder_request_validation_layers(instance_builder)
		vkb.instance_builder_use_default_debug_messenger(instance_builder)
	}

	inst, err := vkb.instance_builder_build(instance_builder)
	if err != nil {
		log.error("Failed to build instance: %#v", err)
		return
	} else {
		log.info("Vulkan instance created successfully")
	}

	vkb_instance = inst
	vk_instance = inst.instance

}

create_device :: proc() {
	if glfw.CreateWindowSurface(vk_instance, window, nil, &vk_surface) != .SUCCESS {
		log.error("Failed to create window surface")
		return
	} else {
		log.info("Window surface created successfully")
	}

	selector := vkb.create_physical_device_selector(vkb_instance)
	defer vkb.destroy_physical_device_selector(selector)

	features_12 := vk.PhysicalDeviceVulkan12Features {
		bufferDeviceAddress = true,
		descriptorIndexing  = true,
	}

	features_13 := vk.PhysicalDeviceVulkan13Features {
		dynamicRendering = true,
		synchronization2 = true,
	}

	vkb.physical_device_selector_set_minimum_version_value(selector, vk.API_VERSION_1_3)
	vkb.physical_device_selector_set_required_features_12(selector, features_12)
	vkb.physical_device_selector_set_required_features_13(selector, features_13)
	vkb.physical_device_selector_set_surface(selector, vk_surface)

	phys_dev, phys_err := vkb.physical_device_selector_select(selector)
	if phys_err != nil {
		log.error("Failed to select physical device: %#v", phys_err)
		return
	} else {
		log.info("Physical device selected successfully")
	}

	vkb_physical_device = phys_dev
	vk_physical_device = phys_dev.physical_device

	device_builder := vkb.create_device_builder(vkb_physical_device)
	defer vkb.destroy_device_builder(device_builder)

	dev, dev_err := vkb.device_builder_build(device_builder)
	if dev_err != nil {
		log.error("Failed to get logical device: %#v", dev_err)
		return
	} else {
		log.info("Logical device created successfully")
	}

	vkb_device = dev
	vk_device = dev.device

}

create_queue :: proc() {

	// queue
	queue, queue_err := vkb.device_get_queue(vkb_device, .Graphics)
	if queue_err != nil {
		log.error("Failed to get graphics queue: %#v", queue_err)
		return
	} else {
		log.info("Graphics queue get successfully")
	}

	queue_family, queue_family_err := vkb.device_get_queue_index(vkb_device, .Graphics)
	if queue_family_err != nil {
		log.error("Failed to get graphics family: %#v", queue_family_err)
		return
	} else {
		log.info("Graphics family chosen successfully")
	}

	graphics_queue = queue
	graphics_queue_family = queue_family

}

create_allocator :: proc() {
	vma_vulkan_functions := vma.create_vulkan_functions()

	allocator_create_info: vma.Allocator_Create_Info = {
		flags            = {.Buffer_Device_Address},
		instance         = vk_instance,
		physical_device  = vk_physical_device,
		device           = vk_device,
		vulkan_functions = &vma_vulkan_functions,
	}

	if !vk_check(vma.create_allocator(allocator_create_info, &vma_allocator)) {
		log.error("Failed to create vulkan memory allocator")
		return
	} else {
		log.info("Created vulkan memory allocator successfully")
	}

}

create_swapchain :: proc() {

	w, h := glfw.GetWindowSize(window)
	swapchain_extent.width = u32(w)
	swapchain_extent.height = u32(h)

	swapchain_format = .B8G8R8A8_UNORM

	swapchain_builder := vkb.create_swapchain_builder(vkb_device)
	defer vkb.destroy_swapchain_builder(swapchain_builder)

	vkb.swapchain_builder_set_desired_format(
		swapchain_builder,
		{format = swapchain_format, colorSpace = .SRGB_NONLINEAR},
	)
	vkb.swapchain_builder_set_desired_present_mode(swapchain_builder, .FIFO)
	vkb.swapchain_builder_set_desired_extent(
		swapchain_builder,
		swapchain_extent.width,
		swapchain_extent.height,
	)
	vkb.swapchain_builder_add_image_usage_flags(swapchain_builder, {.TRANSFER_DST})

	swap, swap_err := vkb.swapchain_builder_build(swapchain_builder)
	if swap_err != nil {
		log.error("Failed to build swapchain: %#v", swap_err)
		return
	}

	vkb_swapchain = swap
	vk_swapchain = swap.swapchain
	swapchain_extent = swap.extent

	images, img_err := vkb.swapchain_get_images(vkb_swapchain)
	if img_err == nil {
		swapchain_images = images
	}

	views, view_err := vkb.swapchain_get_image_views(vkb_swapchain)
	if view_err == nil {
		swapchain_image_views = views
	}

	log.info("Swapchain created successfully at", swapchain_extent.width, swapchain_extent.height)
}

create_commands :: proc() {

	command_pool_info := command_pool_create_info(graphics_queue_family, {.RESET_COMMAND_BUFFER})

	for &frame in frames {
		if !vk_check(
			vk.CreateCommandPool(vk_device, &command_pool_info, nil, &frame.command_pool),
		) {
			log.error("Failed to create command pool")
			return
		} else {
			log.info("Command pool created successfully")
		}

		cmd_alloc_info := command_buffer_allocate_info(frame.command_pool)
		if !vk_check(
			vk.AllocateCommandBuffers(vk_device, &cmd_alloc_info, &frame.main_command_buffer),
		) {
			log.error("Failed to allocate command buffer")
			return
		} else {
			log.info("Command buffer allocated successfully")
		}

	}

}

init_sync :: proc() {
	fence_create_info := fence_create_info({.SIGNALED})
	semaphore_create_info := semaphore_create_info()

	for &frame in frames {
		if !vk_check(vk.CreateFence(vk_device, &fence_create_info, nil, &frame.render_fence)) {
			log.error("Failed to create fence")
			return
		} else {
			log.info("Fence created successfully")
		}

		if !vk_check(
			vk.CreateSemaphore(vk_device, &semaphore_create_info, nil, &frame.swapchain_semaphore),
		) {
			log.error("Failed to create swapchain semaphore")
			return
		} else {
			log.info("Swapchain semaphore created successfully")
		}

		if !vk_check(
			vk.CreateSemaphore(vk_device, &semaphore_create_info, nil, &frame.render_semaphore),
		) {
			log.error("Failed to create render semaphore")
			return
		} else {
			log.info("Render semaphore created successfully")
		}
	}
}

draw :: proc() {
	frame := get_current_frame()

	// begin render
	if !vk_check(vk.WaitForFences(vk_device, 1, &frame.render_fence, true, 1e9)) {return}
	if !vk_check(vk.ResetFences(vk_device, 1, &frame.render_fence)) {return}
	log.info("GPU is finished rendering")

	if !vk_check(
		vk.AcquireNextImageKHR(
			vk_device,
			vk_swapchain,
			1e9,
			frame.swapchain_semaphore,
			0,
			&frame.swapchain_image_index,
		),
	) {
		log.error("Failed to request image from swapchain")
		return
	} else {
		log.info("Request image from swapchain successfully")
	}

	cmd := frame.main_command_buffer

	if !vk_check(vk.ResetCommandBuffer(cmd, {})) {return}

	cmd_begin_info := command_buffer_begin_info({.ONE_TIME_SUBMIT})
	if !vk_check(vk.BeginCommandBuffer(cmd, &cmd_begin_info)) {
		log.error("Failed to begin command buffer recording")
		return
	} else {
		log.info("Begin command bufffer recording successfully")
	}

	// render starts here
	transition_image(cmd, swapchain_images[frame.swapchain_image_index], .UNDEFINED, .GENERAL)

	flash := abs(math.sin(f32(frame_number / 5.0)))
	clear_value := vk.ClearColorValue {
		float32 = {0.0, 0.0, flash, 1.0},
	}

	clear_range := image_subresource_range({.COLOR})

	vk.CmdClearColorImage(
		cmd,
		swapchain_images[frame.swapchain_image_index],
		.GENERAL,
		&clear_value,
		1,
		&clear_range,
	)

	transition_image(
		cmd,
		swapchain_images[frame.swapchain_image_index],
		.GENERAL,
		.PRESENT_SRC_KHR,
	)

	if !vk_check(vk.EndCommandBuffer(cmd)) {
		log.error("Failed to end command buffer recording")
		return
	} else {
		log.info("End command bufffer recording successfully")
	}

	// submit render
	cmd_info := command_buffer_submit_info(cmd)
	signal_info := semaphore_submit_info({.ALL_GRAPHICS}, frame.render_semaphore)
	wait_info := semaphore_submit_info({.COLOR_ATTACHMENT_OUTPUT_KHR}, frame.swapchain_semaphore)

	submit := submit_info(&cmd_info, &signal_info, &wait_info)

	if !vk_check(vk.QueueSubmit2(graphics_queue, 1, &submit, frame.render_fence)) {
		log.error("Failed to submit command buffer to the queue")
		return
	} else {
		log.info("Submit command buffer to the queue successfully")
	}

	// present render
	present_info := vk.PresentInfoKHR {
		sType              = .PRESENT_INFO_KHR,
		pSwapchains        = &vk_swapchain,
		swapchainCount     = 1,
		pWaitSemaphores    = &frame.render_semaphore,
		waitSemaphoreCount = 1,
		pImageIndices      = &frame.swapchain_image_index,
	}

	if !vk_check(vk.QueuePresentKHR(graphics_queue, &present_info)) {
		log.error("Failed to present image")
		return
	} else {
		log.info("Image presented into the screen successfully")
	}

	frame_number += 1
}

cleanup :: proc() {

	ensure(vk.DeviceWaitIdle(vk_device) == vk.Result.SUCCESS)

	destroy_command_pool()
	destroy_swapchain()
	vkb.destroy_device(vkb_device)
	vkb.destroy_surface(vkb_instance, vk_surface)
	vkb.destroy_instance(vkb_instance)
}

destroy_swapchain :: proc() {
	vkb.swapchain_destroy_image_views(vkb_swapchain, swapchain_image_views)
	vkb.destroy_swapchain(vkb_swapchain)
	delete(swapchain_image_views)
	delete(swapchain_images)
}

destroy_command_pool :: proc() {
	for &frame in frames {
		vk.DestroyCommandPool(vk_device, frame.command_pool, nil)

		// destroy sync objects
		vk.DestroyFence(vk_device, frame.render_fence, nil)
		vk.DestroySemaphore(vk_device, frame.render_semaphore, nil)
		vk.DestroySemaphore(vk_device, frame.swapchain_semaphore, nil)
	}
}
