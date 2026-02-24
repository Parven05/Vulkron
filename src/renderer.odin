package vulkron

import "core:log"
import "vendor:glfw"
import vk "vendor:vulkan"

import "../libs/vkb"

// glfw
window: glfw.WindowHandle

// vulkan
// init
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

// vk-bootstrap
vkb_instance: ^vkb.Instance
vkb_physical_device: ^vkb.Physical_Device
vkb_device: ^vkb.Device
vkb_swapchain: ^vkb.Swapchain

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

init_vulkan :: proc() {
	create_instance()
	if vkb_instance != nil {
		create_device()
		create_swapchain()
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
		log.info("Window surface created")
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

destroy_swapchain :: proc() {
	vkb.swapchain_destroy_image_views(vkb_swapchain, swapchain_image_views)
	vkb.destroy_swapchain(vkb_swapchain)
	delete(swapchain_image_views)
	delete(swapchain_images)
}

draw :: proc() {
	for !glfw.WindowShouldClose(window) {
		glfw.PollEvents()
	}
}

cleanup :: proc() {
	destroy_swapchain()
	vkb.destroy_device(vkb_device)
	vkb.destroy_surface(vkb_instance, vk_surface)
	vkb.destroy_instance(vkb_instance)
}
