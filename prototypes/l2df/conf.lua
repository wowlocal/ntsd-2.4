function love.conf(t)
  t.identity = 'ntsd-l2df-prototype'
  t.version = '11.5'
  t.window.title = 'NTSD · L2DF native prototype'
  t.window.width, t.window.height = 1152, 720
  t.window.resizable = true
  t.window.vsync = 1
  t.modules.physics = false
  t.console = true
end
