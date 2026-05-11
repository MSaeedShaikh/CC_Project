FROM node:20-slim AS css-builder
WORKDIR /build
COPY package*.json ./
RUN npm ci
COPY app/static/input.css ./app/static/input.css
COPY app/templates ./app/templates
RUN npx @tailwindcss/cli -i ./app/static/input.css -o ./app/static/output.css --minify

FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
COPY --from=css-builder /build/app/static/output.css ./app/static/output.css
EXPOSE 8080
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:8080", "run:app"]
