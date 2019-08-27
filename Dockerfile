FROM node:8.11.1

# RUN mkdir -p /usr/app
WORKDIR /usr/app
COPY . .

ENV PORT 3000
ENV DB_CONNECTION_STRING mongodb://mongo

# Avoid old npm security vulnerabilities
RUN npm i npm@6.11.2 -g
RUN npm install
RUN npm audit fix
# RUN npm ci --only=production
CMD ["npm", "start"]

# Using RUN instead of CMD 
#   to be sure docker node doesn't start if the app fails
# RUN npm start
EXPOSE ${PORT}

