# clean up old wheels
rm -f dist/*.whl
poetry install
poetry build --format=wheel