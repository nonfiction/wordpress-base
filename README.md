# PHP/Apache base image for Wordpress

This extends `php:8.1-apache` with a few additional packages we rely on for
deploying Wordpress websites.

## Usage:

```dockerfile
FROM nonfiction/wordpress-base:v3
# ...
```

## Makefile commands:  

```
make update
make build
make push
make shell
```

## Related Repositories

- [nonfiction/wordpress](https://github.com/nonfiction/wordpress)
- [nonfiction/wordpress-cron](https://github.com/nonfiction/wordpress-cron)
- [nonfiction/platform](https://github.com/nonfiction/platform)
- [nonfiction/traefik](https://github.com/nonfiction/traefik)
