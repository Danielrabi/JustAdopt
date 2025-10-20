FROM python:3.10-slim
WORKDIR /usr/src/app
RUN apt-get update -y && apt-get install -y build-essential && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
COPY templates ./templates
RUN pip3 install --no-cache-dir -r requirements.txt
COPY app.py .
EXPOSE 5000
CMD ["python3", "/usr/src/app/app.py"]