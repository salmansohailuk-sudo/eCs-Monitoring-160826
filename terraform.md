## Create Database Tables from `createdatabase.sql`

Run the following commands from the SQL/project folder on your EC2 instance.

### 1. Navigate to the project directory

```bash
cd /home/ec2-user/ecomm
```

### 2. Run `createdatabase.sql` against RDS

Run this **exact command**:

```bash
sudo docker run --rm \
  -v "$(pwd):/sql" \
  mysql:8.0 \
  sh -c 'mysql -h ecomm-db.c5kaeq8us34x.us-east-1.rds.amazonaws.com -u admin -pCloud123 ecomm < /sql/createdatabase.sql'
```

This mounts the current directory into the MySQL 8.0 container and executes:

```text
createdatabase.sql
```

against the `ecomm` database on the RDS MySQL instance.

### 3. Connect to the RDS database

Once the SQL file has been executed successfully, connect to RDS using:

```bash
sudo docker run -it --rm mysql:8.0 \
  mysql -h ecomm-db.c5kaeq8us34x.us-east-1.rds.amazonaws.com \
  -u admin \
  -pCloud123 \
  ecomm
```

### 4. Check the tables

Inside the MySQL prompt, run:

```sql
SHOW TABLES;
```

You should now see the tables created by `createdatabase.sql`.

### 5. Exit MySQL

```sql
EXIT;
```
