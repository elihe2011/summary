# 1. 简介

Spring 家族：

- Spring Framework  核心和基础
- Spring Boot
- Spring Data
- Spring Cloud
- String Security



**Sprint Framework**：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/java/spring-framework.png) 

模块说明：

- Core：Spring 运行的核心
  - **IoC：控制反转，依赖注入**
  - **AOP：面向切面编程**
  - Events：事件处理机制，包括事件类ApplicationEvent和事件监听类ApplicationListener。实现了ApplicationListener接口的bean部署到Spring容器中，则每次ApplicationEvent发布到ApplicationContext时，都会通知该 bean.
  - Resources：资源加载，比如Url资源加载，配置文件xml加载
  - i18n：国际化
  - Validation：数据校验
  - Data Binding：数据绑定
  - Type Conversion：类型转换，SpringMVC中参数的接收使用到
  - SpEL：Spring Expression Language。通常时为了在XML或者注释中方便求值用的，通过编写 `##{}` 这样的格式，即可使用。
- Testing：测试模块
  - Mock Objects
  - TestContext Framework
  - Spring MVC Test
  - WebTestClient
- Data Access：数据库访问
  - Transaction
  - DAO Support
  - JDBC
  - O/R Mapping
  - XML Marshlling
- Web Servlet：传统 Web Servlet 的支持
  - Spring WebFlux
  - WebClient
  - WebSocket
- Integration：第三方系统支持
  - Remoting
  - JMS
  - JCA
  - JMX
  - Email
  - Tasks
  - Scheduling
  - Caching
- Languages 对其他JVM语言支持
  - Groovy
  - Kotlin



# 2. IoC

## 2.1 IoC 容器

IoC：Inversion of Control，控制反转

### 2.1.1 控制反转

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/java/spring-without-ioc.png) 

机械手臂结构图，各个齿轮分别带动时针、分针和秒针顺时针旋转，协同工作，共同完成某些任务。**但如果一个齿轮出现问题，将会影响整个齿轮组的正常运转**。

软件专家 Michael Mattson 1996年提出IoC理论，用来实现对象之间的“解耦”。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/java/spring-with-ioc.png) 

引入第三方IoC容器，齿轮之间的传动全部依赖“第三方”，全部对象的控制权全部上交给 IoC容器。

**IoC：<font color="red">控制反转，将对象(或资源)的控制权由应用程序转交给容器</font>。**



### 2.1.2 依赖注入

在Spring中，创建对象的行为由 IoC 容器负责，那必然需要一种注入机制，将对象注入到应用程序中。

依赖注入的两种方式：

- set 注入

  ```java
  public void setDataSource(DataSource dataSource) {
      this.dataSource = dataSource;
  }
  ```

- 构造器注入

  ```java
  public UserService(DataSource dataSource){
      this.dataSource = dataSource;
  }
  ```

  

### 2.1.3 总结

控制反转：**将对象(或资源)的控制权由应用程序转交给IoC容器**

依赖注入：**应用程序所需的资源由IoC容器主动注入**



## 2.2 入门案例

IoC 容器使用的核心包：`org.springframework.beans`和`org.springframework.context`

### 2.2.1 工程搭建

新建maven工程，pom.xml如下：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.elihe.learn</groupId>
    <artifactId>spring01</artifactId>
    <version>1.0-SNAPSHOT</version>

    <properties>
        <maven.compiler.source>1.8</maven.compiler.source>
        <maven.compiler.target>1.8</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework</groupId>
            <artifactId>spring-core</artifactId>
            <version>5.2.16.RELEASE</version>
        </dependency>

        <dependency>
            <groupId>org.springframework</groupId>
            <artifactId>spring-context</artifactId>
            <version>5.2.16.RELEASE</version>
        </dependency>

        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <version>1.18.20</version>
        </dependency>
    </dependencies>

</project>
```



### 2.2.2 Domain

```java
package com.elihe.domain;

import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class User {
    private Long UserId;

    private String nickname;

    private String mail;

    private String password;
}
```



### 2.2.3 Service

```java
package com.elihe.service;

import com.elihe.domain.User;

public class MailService {
    public boolean sendRegisterMail(User user) {
        System.out.printf("%s 正在注册", user.getNickname());
        return true;
    }
}
```



```java
package com.elihe.service;

import com.elihe.domain.User;

import java.util.Arrays;
import java.util.List;

public class UserService {
    private List<User> users = Arrays.asList(
            new User(1L, "aaa", "aaa@test.com", "123456"),
            new User(2L, "bbb", "bbb@test.com", "123456"),
            new User(3L, "ccc", "ccc@test.com", "123456")
    );

    private MailService mailService;

    // 注入MailService
    public void setMailService(MailService mailService) {
        this.mailService = mailService;
    }

    public void registerUser(String mail, String password, String nickname) {
        users.forEach(user -> {
            if (user.getMail().equalsIgnoreCase(mail)) {
                throw new RuntimeException("已注册");
            }
        });

        User user = new User(null, mail, password, nickname);
        mailService.sendRegisterMail(user);
    }
}
```



### 2.2.4 配置spring

修改 `resources/application.xml`，增加 Bean 配置：

```xml 
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd">

    <bean id="userService" class="com.elihe.service.UserService">
        <!-- 注入MailService -->
        <property name="mailService" ref="mailService" />
    </bean>

    <bean id="mailService" class="com.elihe.service.MailService" />
</beans>
```

等效于：

```java
UserService userService = new UserService();
MailService mailService = new MailService();
userService.setMailService(mailService);
```



bean 配置属性：

- id：唯一识别
- name：bean的别名，可定义多个，使用逗号(,)分号(;)空格( )分隔
- scope：bean的作用范围 
  - singleton：单例（默认） 
  - prototype：非单例



### 2.2.5 主程序

```java
package com.elihe.learn;

import com.elihe.service.UserService;
import org.springframework.context.ApplicationContext;
import org.springframework.context.support.ClassPathXmlApplicationContext;

public class Main {
    public static void main(String[] args) {
        // 1. 创建IoC容器
        ApplicationContext context = new ClassPathXmlApplicationContext("application.xml");
        
        // 2. 获取Bean实例
        // UserService userService = (UserService) context.getBean("userService"); // 通过ID获取
        UserService userService = context.getBean(UserService.class);              // 通过类型获取
        
        // 3. 调用方法
        userService.registerUser("ddd@test.com", "123456", "ddd");
        System.out.println("Done!");
    }
}
```



## 2.3 IoC 注解

### 2.3.1 注解方式

#### 2.3.1.1 Bean 定义

`@Component`注解，相当于定义了一个Bean，Bean的名称默认是所在类的类名，首字母小写

```java
@Component
public class MailService {}

@Component
public class UserService {}
```



#### 2.3.1.2 Bean 注入

`@Autowired`注解，相当于把指定类型的Bean注入到指定的字段中

```java
    // 注解到字段
    @Autowired
    private MailService mailService;

    // 注解到setter(推荐方式)
    @Autowired
    public void setMailService(MailService mailService) {
        this.mailService = mailService;
    }

    // 注解到构造器
    public UserService(@Autowired MailService mailService){
        this.mailService = mailService;
    }

    // 注解到构造器
    @Autowired
    public UserService(MailService mailService){
        this.mailService = mailService;
    }
```



### 2.3.2 使用注解

#### 2.3.2.1 混合模式

xml 配置中，加入扫包路径，spring启动时，会去对应包下扫描对应的注解

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xmlns:context="http://www.springframework.org/schema/context"
       xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd http://www.springframework.org/schema/context https://www.springframework.org/schema/context/spring-context.xsd">

    <context:component-scan base-package="com.elihe" />
</beans>
```

启动主程序：

```java
package com.elihe.learn;

import com.elihe.service.UserService;
import org.springframework.context.ApplicationContext;
import org.springframework.context.support.ClassPathXmlApplicationContext;

public class Main {
    public static void main(String[] args) {
        ApplicationContext context = new ClassPathXmlApplicationContext("application.xml");
        UserService userService = (UserService) context.getBean("userService");
        userService.registerUser("ddd@test.com", "123456", "ddd");
        System.out.println("Done!");
    }
}
```



#### 2.3.2.2 纯注解

定义Spring配置类：

```java
package com.elihe.config;

import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.Configuration;

@Configuration
@ComponentScan("com.elihe")
public class SpringConfig {
}
```

`@Configuration` 注解：

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Component
public @interface Configuration {}   // 本质上@Configuration就是@Component，只是为了语义的表达
```



启动主程序：

```java
package com.elihe.learn;

import com.elihe.config.SpringConfig;
import com.elihe.service.UserService;
import org.springframework.context.ApplicationContext;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;

public class Main {
    public static void main(String[] args) {
//        ApplicationContext context = new ClassPathXmlApplicationContext("application.xml");
        ApplicationContext context = new AnnotationConfigApplicationContext(SpringConfig.class);
        UserService userService = (UserService) context.getBean("userService");
        userService.registerUser("ddd@test.com", "123456", "ddd");
        System.out.println("Done!");
    }
}
```



### 2.3.3 其他注解

#### 2.3.3.1 @Controller

Controller 层主要负责具体的业务模块流程的控制，通常调用 Service 层的接口来控制业务流程，又被称为 Web层、API层等。一般负责接收参数、解析参数、调用业务逻辑层代码，然后返回给前端

```java
@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Component
public @interface Controller {}
```



#### 2.3.3.2 @Service

Service 层主要负责业务模块的应用逻辑设计，涉及到数据库访问，调用DAO层来实现

```java
@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Component
public @interface Service {}
```



#### 2.3.3.3 @Repository

DAO 层主要做数据持久化工作，负责与数据库进行交互。一般用不到，例如使用Mybatis时，使用@Mapper来标识DAO的接口

```java
@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Component
public @interface Repository {}
```



#### 2.3.3.4 @Bean

一般在使用第三方 Bean 的时候，比如数据库连接池 `HikariDataSource`

```xml
<!-- https://mvnrepository.com/artifact/com.zaxxer/HikariCP -->
<dependency>
    <groupId>com.zaxxer</groupId>
    <artifactId>HikariCP</artifactId>
    <version>3.4.1</version>
</dependency>
```

源码中，没用类似 @Component 注解

```java
public class HikariDataSource extends HikariConfig implements DataSource, Closeable{}
```

使用 @Bean 注解，将第三方Bean交给 Spring 容器统一管理

```java
package com.elihe.config;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class JdbcConfig {
    @Bean
    public HikariDataSource dataSource() {
        HikariConfig config = new HikariConfig();
        config.setDriverClassName("com.mysql.jdbc.Driver");
        config.setJdbcUrl("jdbc:mysql://localhost:3306/spring_db?useUnicode=true&amp;characterEncoding=utf8");
        config.setUsername("root");
        config.setPassword("123456");

        return new HikariDataSource(config);
    }
}
```



# 3. Bean

## 3.1 创建

### 3.1.1 xml 配置

```xml
<bean id="xxxx"  class="xxxx.xxxx"/>
```



### 3.1.2 注解

@Component

@Service

@Controller

@Repository



### 3.1.3 其他注解

@Bean  第三方Bean

@Configuration 声明配置类



### 3.1.4 @Import

```java
@Configuration
@Import(User.class)
public class SpringConfig2 {
}
```

主函数：

```java
public class Main {
    public static void main(String[] args) {
        ApplicationContext context = new AnnotationConfigApplicationContext(SpringConfig.class);
        User bean = context.getBean(User.class);
        System.out.println(bean);
    }
}
```



### 3.1.5 ImportSelector 接口

使用 ImportSelector 接口，配合 @Import 实现：

```java
package com.elihe.domain;

import org.springframework.context.annotation.ImportSelector;
import org.springframework.core.type.AnnotationMetadata;

public class MyImportSelector implements ImportSelector {
    @Override
    public String[] selectImports(AnnotationMetadata annotationMetadata) {
        return new String[]{User.class.getName()};
    }
}
```

Spring配置：

```java
@Configuration
//@Import(User.class)
@Import(MyImportSelector.class)
public class SpringConfig2 {
}
```



使用 ImportBeanDefinitionRegistrar 接口：

```java
package com.elihe.domain;

import org.springframework.beans.factory.config.BeanDefinition;
import org.springframework.beans.factory.support.BeanDefinitionRegistry;
import org.springframework.beans.factory.support.RootBeanDefinition;
import org.springframework.context.annotation.ImportBeanDefinitionRegistrar;
import org.springframework.core.type.AnnotationMetadata;

public class MyImportBeanDefinitionRegistrar implements ImportBeanDefinitionRegistrar {
    @Override
    public void registerBeanDefinitions(AnnotationMetadata annotationMetadata, BeanDefinitionRegistry beanDefinitionRegistry) {
        BeanDefinition beanDefinition = new RootBeanDefinition(User.class.getName());
        beanDefinitionRegistry.registerBeanDefinition(User.class.getName(), beanDefinition);
    }
}
```

Spring配置：

```java
@Configuration
//@Import(User.class)
//@Import(MyImportSelector.class)
@Import(MyImportBeanDefinitionRegistrar.class)
public class SpringConfig2 {
}
```



### 3.1.6 手动注入

某些场景下需要代码动态注入，此时上述方式不适用，需要创建对象手动注入。

通过 DefaultListableBeanFactory 注入：

```java
registerSingleton(String beanName Object object);
```

示例：

```java
package com.elihe.domain;

import org.springframework.beans.BeansException;
import org.springframework.beans.factory.BeanFactory;
import org.springframework.beans.factory.BeanFactoryAware;
import org.springframework.beans.factory.support.DefaultListableBeanFactory;

public class UserRegistrar implements BeanFactoryAware {
    @Override
    public void setBeanFactory(BeanFactory beanFactory) throws BeansException {
        DefaultListableBeanFactory listableBeanFactory = (DefaultListableBeanFactory) beanFactory;

        // 方式一
        /*BeanDefinition beanDefinition = new RootBeanDefinition(User.class);
        listableBeanFactory.registerBeanDefinition(User.class.getName(), beanDefinition);*/

        // 方式二
        User user = new User();
        listableBeanFactory.registerSingleton(User.class.getName(), user);
    }
}
```

Spring配置：

```java
@Configuration
@ComponentScan("com.elihe")
//@Import(User.class)
//@Import(MyImportSelector.class)
//@Import(MyImportBeanDefinitionRegistrar.class)
@Import(UserRegistrar.class)
public class SpringConfig2 {
}
```



## 3.2 作用域

Spring 框架支持5种作用域，其中3种作用域是当开发者基于web的ApplicationContext 时才生效。

| 作用域         | 描述                                                         |
| -------------- | ------------------------------------------------------------ |
| singleton 单例 | 默认，每个Spring IoC容器都拥有唯一的实例对象                 |
| prototype 原型 | 一个Bean定义，任意多个对象                                   |
| request 请求   | 一个HTTP请求会产生一个Bean对象，即每个HTTP请求都有自己的Bean实例。 |
| session 会话   | 限定一个Bean的作用域为 HTTP Session 的生命周期               |
| global session | 限定一个Bean的作用域为全局 HTTP Session 的声明周期，常用于门户网站场景。 |



## 3.3 生命周期

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/java/spring-bean-life-cycle.png) 



示例代码：

```java
package com.elihe.domain;

import org.springframework.beans.BeansException;
import org.springframework.beans.factory.*;
import org.springframework.context.ApplicationContext;
import org.springframework.context.ApplicationContextAware;

public class Person implements BeanNameAware, BeanFactoryAware,
        ApplicationContextAware, InitializingBean, DisposableBean {
    private String name;

    public Person() {
        System.out.println("Person类构造方法");
    }

    public void setName(String name) {
        this.name = name;
        System.out.println("set方法被调用");
    }

    public void myInit() {
        System.out.println("myInit被调用");
    }

    public void myDestroy() {
        System.out.println("myDestroy被调用");
    }

    @Override
    public void destroy() throws Exception {
        System.out.println("destroy被调用");
    }

    @Override
    public void afterPropertiesSet() throws Exception {
        System.out.println("afterPropertiesSet被调用");
    }

    @Override
    public void setApplicationContext(ApplicationContext applicationContext) throws BeansException {
        System.out.println("setApplicationContext被调用");
    }

    @Override
    public void setBeanFactory(BeanFactory beanFactory) throws BeansException {
        System.out.println("setBeanFactory被调用");
    }

    @Override
    public void setBeanName(String beanName) {
        System.out.println("setBeanName被调用，beanName: " + beanName);
    }

    @Override
    public String toString() {
        return "name is " + name;
    }
}
```



```java
package com.elihe.domain;

import org.springframework.beans.BeansException;
import org.springframework.beans.factory.config.BeanPostProcessor;

public class MyBeanPostProcessor implements BeanPostProcessor {
    @Override
    public Object postProcessBeforeInitialization(Object bean, String beanName) throws BeansException {
        System.out.println("postProcessBeforeInitialization被调用");
        return bean;
    }

    @Override
    public Object postProcessAfterInitialization(Object bean, String beanName) throws BeansException {
        System.out.println("postProcessAfterInitialization被调用");
        return bean;
    }
}
```



```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xmlns:context="http://www.springframework.org/schema/context"
       xsi:schemaLocation="http://www.springframework.org/schema/beans
        https://www.springframework.org/schema/beans/spring-beans.xsd http://www.springframework.org/schema/context https://www.springframework.org/schema/context/spring-context.xsd">

    <context:component-scan base-package="com.elihe" />

    <bean id="person1" destroy-method="myDestroy"
          init-method="myInit" class="com.elihe.domain.Person">
        <property name="name">
            <value>jack</value>
        </property>
    </bean>
    
    <bean id="postProcessor" class="com.elihe.domain.MyBeanPostProcessor" />
</beans>
```



运行：

```java
package com.elihe.learn;

import com.elihe.domain.Person;
import org.springframework.context.ApplicationContext;
import org.springframework.context.support.ClassPathXmlApplicationContext;

public class Main {
    public static void main(String[] args) {
        ApplicationContext context = new ClassPathXmlApplicationContext("application.xml");
        Person bean = context.getBean(Person.class);
        System.out.println(bean);

        ((ClassPathXmlApplicationContext)context).close();
    }
}
```

结果：

```
Person类构造方法
set方法被调用
setBeanName被调用，beanName: person1
setBeanFactory被调用
setApplicationContext被调用
postProcessBeforeInitialization被调用
afterPropertiesSet被调用
myInit被调用
postProcessAfterInitialization被调用
name is jack
destroy被调用
myDestroy被调用
```



## 3.4 List 注入

定义接口：

```java
public interface Validator {
    void validate(String email, String password, String name);
}
```



实现参数验证：

```java
@Component
@Order(1)
public class EmailValidator implements Validator {
    @Override
    public void validate(String email, String password, String name) {
        if (!email.matches("^[a-z0-9]+\\@[a-z0-9]+\\.[a-z]{2,10}$")) {
            throw new IllegalArgumentException("invalid email: " + email);
        }
    }
}

@Component
@Order(2)
public class PasswordValidator implements Validator {
    @Override
    public void validate(String email, String password, String name) {
        if (!password.matches("^.{6,20}$")) {
            throw new IllegalArgumentException("invalid password");
        }
    }
}

@Component
@Order(3)
public class NameValidator implements Validator {
    @Override
    public void validate(String email, String password, String name) {
        if (name == null || name.isEmpty() || name.length() > 20) {
            throw new IllegalArgumentException("invalid name: " + name);
        }
    }
}
```



通过List注入验证：

```java
@Component
public class Validators {
    @Autowired
    List<Validator> validators;

    public void validate(String email, String password, String name) {
        for (Validator validator : this.validators) {
            validator.validate(email, password, name);
        }
    }
}
```



## 3.5 可选注入

默认情况下，增加`@Autowired`注解后，如果没有找到对应类的Bean，它会抛出`NoSuchBeanDefinitionException`异常。

支持指定参数，找不到时忽略

```java
@Component
public class MailService {
    @Autowired(required = false)
    ZoneId zoneId = ZoneId.systemDefault();
    ...
}
```











