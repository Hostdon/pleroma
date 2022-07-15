all:	install
	pipenv run mkdocs build

install:
	pipenv install
clean:
	rm -rf docs
