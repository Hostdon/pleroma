all:	install
	pipenv run mkdocs build

branch := $(shell git rev-parse --abbrev-ref HEAD)
install:
	pipenv install
clean:
	rm -rf site
serve:
	pipenv run python3 -m http.server -d site  
zip:
	zip -r docs.zip site/*
deploy:
	cd site && rclone copy . scaleway:akkoma-docs/$(branch)
