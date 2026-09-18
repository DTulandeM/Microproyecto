FROM python:3.12-alpine

WORKDIR /sitio
COPY sitio/ .

EXPOSE 80

CMD ["python3", "-m", "http.server", "80"]
