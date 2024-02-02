rm -rf dist/
poetry install
poetry build --format=wheel
mkdir dist/python
cp gpg dist/python/
version=$(poetry version | awk '{print $2}')
.venv/bin/pip install dist/pgpcrypto-$version-py3-none-any.whl -t ./dist/python
cd dist
zip -r lambda_layer.zip .