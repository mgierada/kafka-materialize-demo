FROM python:3.11-slim

WORKDIR /app

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Copy project files
COPY pyproject.toml .
COPY producer.py .

# Install dependencies using uv
RUN uv pip install --system -r pyproject.toml

# Run the producer
CMD ["python", "-u", "producer.py"]
