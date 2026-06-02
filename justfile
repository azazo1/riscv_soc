build_dir := "build"
hello_world_dir := join(build_dir, "hello_world")

default:
    @just --list

hello-world:
    @mkdir -p {{ hello_world_dir }}
    @verilator --binary --top-module hello_world --Mdir {{ hello_world_dir }} src/hello_world.v

run-hello-world: hello-world
    @./{{ hello_world_dir }}/Vhello_world

clean:
    @rm -rf {{ build_dir }} obj_dir
