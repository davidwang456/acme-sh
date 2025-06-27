# 使用 OpenJDK 17 作为基础镜像
FROM openjdk:17-jdk-slim

# 设置工作目录
WORKDIR /app

# 复制 Maven 配置文件
COPY pom.xml .

# 复制源代码
COPY src ./src

# 安装 Maven（如果需要）
RUN apt-get update && apt-get install -y maven

# 构建应用
RUN mvn clean package -DskipTests

# 创建 webroot 目录
RUN mkdir -p /tmp/webroot/.well-known/acme-challenge

# 暴露端口
EXPOSE 80

# 设置环境变量
ENV JAVA_OPTS="-Xmx512m -Xms256m"

# 启动应用
CMD ["java", "-jar", "target/acme-challenge-server-1.0.0.jar"]
