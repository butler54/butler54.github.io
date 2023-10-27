# butler.github.io - OSS repo for chris.thebutlers.me

## Tooling
This website is built using [mkdocs](https://www.mkdocs.org/) and [mkdocs-material](https://squidfunk.github.io/mkdocs-material/)

### Testing on a mac
1. [Install homebrew](https://brew.sh/)
2. Install packages with brew
   ```bash
   brew install python cairo
   ```
3. (Recommended) [setup a python virtualenv](https://docs.python.org/3/library/venv.html)
4. `pip install -r requirements.txt`
5. `mkdocs serve`