all:	install
	pipenv run mkdocs build

install:
	pipenv install
clean:
	rm -rf site
serve:
	pipenv run python3 -m http.server -d site  
