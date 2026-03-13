# Use Node.js LTS version
FROM node:22

# Set working directory
WORKDIR /app

# Copy package.json and install dependencies
COPY package*.json ./
RUN npm install

# Copy rest of the application
COPY . .

# Expose port
EXPOSE 3000

# Start the app
CMD ["node", "app/app.js"]
