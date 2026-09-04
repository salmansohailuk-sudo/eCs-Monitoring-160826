Run inside your SQL folder:
Code
cd /home/ec2-user/ecomm
✔ Run this EXACT command:
Code
'''
sudo docker run --rm -v $(pwd):/sql mysql:8.0 \
  sh -c "mysql -h ecomm-db.c5kaeq8us34x.us-east-1.rds.amazonaws.com -u admin -pCloud123 ecomm < /sql/createdatabase.sql"

'''


'''
sudo docker run -it --rm mysql:8.0 \ mysql -h ecomm-db.c5kaeq8us34x.us-east-1.rds.amazonaws.com \ -u admin -pCloud123 ecomm

'''
Code
SHOW TABLES;
You should now see:
