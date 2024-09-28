## Building the docs

You don't need to build and test the docs as long as you make sure the syntax is correct. But in case you do want to build the docs, feel free to do so.

```sh
# Make sure you're in the same directory as this README
# From the root of the Akkoma repo, you'll need to do
cd docs

# Optionally use a virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run an http server who rebuilds when files change
# Accessable on http://127.0.0.1:8000
mkdocs serve

# Build the docs
# The static html pages will have been created in the folder "site"
# You can serve them from a server by pointing your server software (nginx, apache...) to this location
mkdocs build

# To get out of the virtual environment, you do
deactivate
```
