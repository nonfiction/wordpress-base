tag := v5
update: build push
build: ; docker buildx build -t nonfiction/wordpress-base:$(tag) .
push:	 ; docker push nonfiction/wordpress-base:$(tag)
shell: ; docker run -it --rm nonfiction/wordpress-base:$(tag) bash
