rm -rf dist/
poetry install
poetry build --format=wheel
mkdir dist/python
cp gpg dist/python/
.venv/bin/pip install dist/pgpcrypto-0.1.0-py3-none-any.whl -t ./dist/python
cd dist
zip -r lambda_layer.zip .