function love.conf(t)
 t.window=false
 for _,name in ipairs({'audio','graphics','image','joystick','keyboard','mouse','physics','sound','touch','video'}) do t.modules[name]=false end
 t.console=true
end
