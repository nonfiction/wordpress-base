tag := v1
update: build push
build: ; docker buildx build -t nonfiction/apache-php:$(tag) .
push:	 ; docker push nonfiction/apache-php:$(tag)
shell: ; docker run -it --rm nonfiction/apache-php:$(tag) sh
