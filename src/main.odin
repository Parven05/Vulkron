package vulkron

import "core:log"
import "vendor:glfw"

main :: proc() {
	context.logger = log.create_console_logger()

	if !glfw.Init() {
		log.error("Failed to initialize GLFW")
		return
	}
	defer glfw.Terminate()

	init_glfw_window()

	if window == nil {return}
	defer glfw.DestroyWindow(window)

	start()

	for !glfw.WindowShouldClose(window) {
		glfw.PollEvents()
		draw()
	}

	cleanup()
}
