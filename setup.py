from setuptools import setup, find_packages

exec(open("trio_inspector/_version.py", encoding="utf-8").read())

LONG_DESC = open("README.md", encoding="utf-8").read()

setup(
    name="trio-inspector",
    version=__version__,
    description="A browser-based monitor for Trio",
    url="https://github.com/syncrypt/trio-inspector.git",
    long_description=open("README.md").read(),
    author="Hannes Gräuler",
    author_email="hannes@syncrypt.space",
    license="MIT -or- Apache License 2.0",
    packages=find_packages(),
    package_data={
        'trio_inspector': [
            'static/main.js',
            'static/index.html',
            'static/style.css'
        ]
    },
    install_requires=[
        "trio",
        "hypercorn",
        "quart-trio",
        "quart",
        "quart-cors"
    ],
    keywords=[
        # COOKIECUTTER-TRIO-TODO: add some keywords
        # "async", "io", "networking", ...
    ],
    python_requires=">=3.5",
    classifiers=[
        "License :: OSI Approved :: MIT License",
        "License :: OSI Approved :: Apache Software License",
        "Framework :: Trio",
        "Operating System :: POSIX :: Linux",
        "Operating System :: MacOS :: MacOS X",
        "Operating System :: Microsoft :: Windows",
        "Programming Language :: Python :: 3 :: Only",
        "Programming Language :: Python :: Implementation :: CPython",
        "Programming Language :: Python :: Implementation :: PyPy",
        "Development Status :: 3 - Alpha",

        # COOKIECUTTER-TRIO-TODO: Consider adding trove classifiers for:
        #
        # - Development Status
        # - Intended Audience
        # - Topic
        #
        # For the full list of options, see:
        #   https://pypi.python.org/pypi?%3Aaction=list_classifiers
    ],
)
