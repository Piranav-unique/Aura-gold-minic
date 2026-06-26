# Railway entrypoint — API lives in backend/
FROM python:3.11-slim as builder

WORKDIR /app
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.11-slim as runner

WORKDIR /app
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -m -s /bin/bash appuser

COPY --from=builder /usr/local /usr/local
COPY --chown=appuser:appgroup backend/ /app

RUN chmod +x entrypoint.sh

ENV PYTHONUNBUFFERED=1
USER appuser
EXPOSE 8000

CMD ["sh", "entrypoint.sh"]
