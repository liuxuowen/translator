# Use an official Python runtime as a parent image
# python:3.10-slim is based on Debian, making it a perfect match for your Debian server
FROM python:3.10-slim

# Set the working directory in the container
WORKDIR /app

# Ensure Python output is sent straight to terminal
ENV PYTHONUNBUFFERED=1

# Prevent debconf from complaining about non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
# ffmpeg might be useful for audio handling if needed in future
RUN apt-get update && apt-get install -y \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy the requirements file into the container
COPY requirements.txt .

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY . .

# Make port 8000 available to the world outside this container
EXPOSE 8000

# Define environment variable
# ENV DASHSCOPE_API_KEY=needs_to_be_set

# Run app.py when the container launches
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
