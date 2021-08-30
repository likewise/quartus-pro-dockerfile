.ONESHELL:

build:
	docker build --network=host -t quartus .
run:
	# mounts current host directory as ~/project/ inside container
	docker run -ti --rm -e LM_LICENSE_FILE -e DISPLAY=$(DISPLAY) -v /tmp/.X11-unix:/tmp/.X11-unix -v $$PWD:/home/quartus/project -w /home/quartus/project quartus:latest

# -v ~/.Xilinx/Xilinx.lic:/home/quartus/.Xilinx/Xilinx.lic:ro 