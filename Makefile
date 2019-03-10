all: wheel

ui/node_modules:
	(cd ui/; npm i --no-save)

trio_inspector/static/main.js: ui/src/ui.elm ui/node_modules
	(cd ui/; npx elm make src/ui.elm --output=../trio_inspector/static/main.js)

trio_inspector/static/style.css: ui/static/style.css
	cp ui/static/style.css trio_inspector/static/style.css

trio_inspector/static/index.html: ui/static/index.html
	cp ui/static/index.html trio_inspector/static/index.html

wheel: trio_inspector/static/main.js trio_inspector/static/style.css trio_inspector/static/index.html
	python setup.py bdist_wheel
