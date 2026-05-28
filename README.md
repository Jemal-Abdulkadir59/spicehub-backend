# SpiceHub Backend 🚀

Backend service for the **SpiceHub** application built using modern technologies including Docker, PostgreSQL, and Hasura GraphQL Engine.

---

## 📦 Tech Stack

* PostgreSQL (Dockerized)
* Hasura GraphQL Engine
* Docker & Docker Compose

---

## ⚙️ Project Setup

### 1. Clone the Repository

```bash
git clone https://github.com/Jemal-Abdulkadir59/spicehub-backend.git
cd spicehub-backend
```

---

### 2. Start Services with Docker

```bash
docker-compose up -d
```

This will start:

* PostgreSQL database
* Hasura GraphQL Engine
* Data Connector (if configured)

---

### 3. Check Running Containers

```bash
docker ps
```

---

## 🌐 Access Services

* GraphQL Engine: http://localhost:8080
* Data Connector: http://localhost:8081

---

## 🗄️ Database Management

### Backup Database

```bash
docker exec -t spicehub-backend-postgres-1 pg_dump -U postgres -d postgres > backup.sql
```

---

### Restore Database

```bash
cat backup.sql | docker exec -i spicehub-backend-postgres-1 psql -U postgres -d postgres
```

---

## 📁 Project Structure

```
spicehub-backend/
│── docker-compose.yml
│── backup.sql (DB backdup)
│── note
│── setup
│── 
```

## 📌 Future Improvements

* Deploy to AWS (ECS / EC2)
* Use AWS RDS instead of local Postgres
* Automate backups to S3
* Add CI/CD pipeline

---

## 👨‍💻 Author

**Jemal Abdulkadir**

