package main

import "core:fmt"
import "vendor:glfw"
import vk "vendor:vulkan"

import "../libs/vkb"

window: glfw.WindowHandle

vk_instance: vk.Instance
vk_surface: vk.SurfaceKHR
vk_device: vk.Device
vk_physical_device: vk.PhysicalDevice

vkb_instance: ^vkb.Instance
vkb_physical_device: ^vkb.Physical_Device
vkb_device: ^vkb.Device

main :: proc() {
	if !glfw.Init() {
		fmt.println("Failed to initialize GLFW")
		return
	}
	defer glfw.Terminate()

	init_glfw_window()
	if window == nil {return}
	defer glfw.DestroyWindow(window)

	// start
	init_vulkan()

	if vkb_device != nil {draw()}

	if vkb_device != nil {vkb.destroy_device(vkb_device)}
	if vk_surface != 0 {vkb.destroy_surface(vkb_instance, vk_surface)}
	if vkb_instance != nil {vkb.destroy_instance(vkb_instance)}
}

init_glfw_window :: proc() {
	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
	glfw.WindowHint(glfw.RESIZABLE, glfw.FALSE)

	window = glfw.CreateWindow(800, 600, "Vulkron", nil, nil)
	if window == nil {
		fmt.println("Failed to create GLFW window")
	} else {
		fmt.printfln("Window created successfully")
	}
}

init_vulkan :: proc() {
	create_instance()
	if vkb_instance != nil {
		create_device()
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
		fmt.eprintfln("Failed to build instance: %#v", err)
		return
	} else {
		fmt.printfln("Vulkan instance created")
	}

	vkb_instance = inst
	vk_instance = inst.instance
}

create_device :: proc() {
	if glfw.CreateWindowSurface(vk_instance, window, nil, &vk_surface) != .SUCCESS {
		fmt.println("Failed to create window surface")
		return
	} else {
		fmt.printfln("Window surface created")
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
		fmt.eprintfln("Failed to select physical device: %#v", phys_err)
		return
	} else {
		fmt.printfln("Physical device selected successfully")
	}
	vkb_physical_device = phys_dev
	vk_physical_device = phys_dev.physical_device

	device_builder := vkb.create_device_builder(vkb_physical_device)
	defer vkb.destroy_device_builder(device_builder)

	dev, dev_err := vkb.device_builder_build(device_builder)
	if dev_err != nil {
		fmt.eprintfln("Failed to get logical device: %#v", dev_err)
		return
	} else {
		fmt.printfln("Logical device created successfully")
	}
	vkb_device = dev
	vk_device = dev.device
}

draw :: proc() {
	for !glfw.WindowShouldClose(window) {
		glfw.PollEvents()
	}
}
