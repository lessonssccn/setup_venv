IMAGE_NAME=ubuntu

# Minimal stage
build-min:
	docker build --target minimal -t $(IMAGE_NAME)-minimal .

run-min:
	docker run -it --rm -v .:/test $(IMAGE_NAME)-minimal /bin/bash