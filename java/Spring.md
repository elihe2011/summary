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



# 4. AOP

AOP，面向切面编程。在不改变原有功能的基础上，对其功能进行增强。

对于 `参数检查`, `日志记录`, `事务处理` 等非核心业务逻辑操作，会频繁的、重复地出现在各个方法中，使用 OOP 思想，很难将这些代码模块化。此时可使用 AOP，通过 Proxy 方式，将重复的公共代码抽离出去，动态植入原有业务逻辑中，而不改变原有的代码解构。



## 4.1 AOP原理

Java 平台上，三种 AOP 植入方式：

- 编译期：编译时，由编译器把切面调用编译进字节码。该方式需要定义新的关键字并扩展编译器，AspectJ 就扩展了 Java 编译器，使用关键字 aspect 来实现植入。
- 类加载器：在目标类被装载到 JVM 时，通过一个特殊的类加载器，对目标类的字节码重新“增强”。
- 运行期：目标对象和切面都是普通Java类，通过JVM动态代理功能或第三方库实现运行期动态植入。



Spring 的AOP实现基于 JVM 的动态代理，支持两种代理：

- JDK动态代理：Spring 的 AOP 默认实现，要求必须实现接口
- CGLIB 动态代理：Spring 的 AOP 的可选配置，类和接口都支持



**JDK 动态代理实例：**

```java
package com.elihe.service;

public interface BookService {
    void createBook();
}

public class BookServiceImpl implements BookService {
    @Override
    public void createBook() {
        System.out.println("create book...");
    }
}
```

代理程序：jdk17+

```java
package com.elihe.proxy;

import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;

public class JDKProxy {
    public Object createBookServiceProxy(Class clazz) {
        ClassLoader classLoader = clazz.getClassLoader();

        Class[] classes = clazz.getInterfaces();

        InvocationHandler invocationHandler = new InvocationHandler() {
            @Override
            public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
                System.out.println("检查参数");

                Object result = method.invoke(clazz.getDeclaredConstructor().newInstance(), args);

                System.out.println("事务处理");
                System.out.println("日志记录");

                return result;
            }
        };

        return Proxy.newProxyInstance(classLoader, classes, invocationHandler);
    }
}
```

主函数：

```java
package com.elihe.learn;

import com.elihe.proxy.JDKProxy;
import com.elihe.service.BookService;
import com.elihe.service.BookServiceImpl;

public class Main {
    public static void main(String[] args) {
        BookService bookService = new BookServiceImpl();
        BookService jdkProxy = (BookService) new JDKProxy().createBookServiceProxy(bookService.getClass());
        jdkProxy.createBook();
    }
}
```



## 4.2 AOP 概念

- Aspect：切面，即一个跨多个核心逻辑的功能，或称为系统关注点
- Joinpoint：连接点，即定义在应用程序流程的何处插入切面的执行
- Pointcut：切入点，即一组连接点的集合
- Advice：通知，即特定连接点上执行的动作
- Introduction：引介，即为一个已有的Java对象动态增加新的接口
- Weaving：织入，即将切面整合到程序的执行流程中
- Interceptor：拦截器，是一种实现增强的方式
- Target Object：目标对象，即真正执行业务的核心逻辑对象
- AOP Proxy：AOP代理，即客户端持有的增强后的对象引用



## 4.3 入门案例

引入支撑包，该依赖会自动引入 AspectJ，使用 AspectJ 实现 AOP 比较方便

```xml
<dependency>
    <groupId>org.springframework</groupId>
    <artifactId>spring-aspects</artifactId>
    <version>5.2.16.RELEASE</version>
</dependency>
```



### 4.3.1 切面类

```java
package com.elihe.aop;

import com.alibaba.fastjson.JSON;
import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.Signature;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Pointcut;
import org.springframework.stereotype.Component;

@Aspect
@Component
@Slf4j
public class LogAspect {
    // 定义切入点，在执行UserService的方法前执行
    @Pointcut("execution(public * com.elihe.service.UserService.*(..))")
    public void pt() {}

    // 定义通知
    @Around("pt()")
    public Object doLogging(ProceedingJoinPoint pjp) throws Throwable {
        try {
            log.info("---------------------log start-------------------");

            // 1. 打印执行的类和方法
            Signature signature = pjp.getSignature();
            String methodName = signature.getName();
            String interfaceName = signature.getDeclaringTypeName();
            log.info("接口名称：{}", interfaceName);
            log.info("方法名称：{}", methodName);

            // 2. 打印方法的参数
            log.info("方法参数：{}", JSON.toJSONString(pjp.getArgs()));

            // 3. 计算方法执行时间
            long startTime = System.currentTimeMillis();

            // 调用方法
            Object result = pjp.proceed();

            long endTime = System.currentTimeMillis();
            log.info("方法执行时间：{}ms", endTime-startTime);

            log.info("---------------------log end-------------------");
            return result;
        } catch (Exception e) {
            // 4. 记录异常
            log.error("异常信息", e);
            throw e;
        }
    }
}
```



### 4.3.2 Spring配置类

```java
package com.elihe.config;

import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.EnableAspectJAutoProxy;

@Configuration
@ComponentScan("com.elihe")
@EnableAspectJAutoProxy(proxyTargetClass = true)  // 开启AOP支撑，并设置代理为cglib
public class SpringConfig {
}
```



### 4.3.3 启动类

```java
package com.elihe.learn;

import com.elihe.config.SpringConfig;
import com.elihe.service.UserService;
import org.springframework.context.ApplicationContext;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;

public class Main {
    public static void main(String[] args) {
        ApplicationContext context = new AnnotationConfigApplicationContext(SpringConfig.class);
        UserService bean = context.getBean(UserService.class);
        bean.registerUser("sahra@test.com", "123456", "sahra");
    }
}
```



## 4.4 通知类型

五种 AOP 通知类型：

- 前置通知
- 后置通知
- 环绕通知 （重点）
- 返回后通知 （了解）
- 抛出异常后通知 （了解）



### 4.4.1 前置通知

- 名称：@Before

- 位置：通知方法定义上方

- 作用：设置当前通知方法与切入点之间的绑定关系，当前通知方法在原始切入点方法**前**执行

- 示例：

  ```java
  @Before("pt()")
  public void before() {
      System.out.println("before advice ...");
  }
  ```



### 4.4.2 后置通知

- 名称：@After

- 位置：通知方法定义上方

- 作用：设置当前通知方法与切入点之间的绑定关系，当前通知方法在原始切入点方法**后**执行

- 示例：

  ```java
  @After("pt()")
  public void after() {
      System.out.println("after advice ...");
  }
  ```



### 4.4.3 环绕通知

- 名称：@Around

- 位置：通知方法定义上方

- 作用：设置当前通知方法与切入点之间的绑定关系，当前通知方法在原始切入点方法**前后**执行

- 示例：

  ```java
  @Around("pt()")
  public Object around(ProceedingJoinPoint pjp) throws Throwable {
      System.out.println("around before advice ...");
      Object ret = pjp.proceed();
      System.out.println("around after advice ...");
      return ret;
  }
  ```



### 4.4.4 返回后通知

- 名称：@AfterReturning

- 位置：通知方法定义上方

- 作用：设置当前通知方法与切入点之间的绑定关系，当前通知方法在原始切入点方法**正常执行完毕后**执行

- 示例：

  ```java
  @AfterReturning("pt()")
  public void afterReturning() {
      System.out.println("afterReturning advice ...");
  }
  ```



### 4.4.5 抛出异常后通知

- 名称：@AfterThrowing

- 位置：通知方法定义上方

- 作用：设置当前通知方法与切入点之间的绑定关系，当前通知方法在原始切入点方法**抛出异常后**执行

- 示例：

  ```java
  @AfterThrowing("pt()")
  public void afterThrowing() {
      System.out.println("afterThrowing advice ...");
  }
  ```



## 4.5 切点表达式

`execute (public User com.elihe.service.UserService.findById (int))`

- 动作关键字：execution
- 访问修饰符：public, private等，可省略
- 返回值
- 包.类/接口.方法名
- 参数
- 异常：方法抛出的异常，可省略

使用通配符：

- `*`：单个独立的任意符号

  ```java
  // 匹配包下的任意包中的UserService类或接口中所有find开头的带有一个参数的方法
  execution(public * com.mszlu.*.UserService.find*(*))
  ```

- `..`：多个连续的任意符合

  ```java
  // 匹配com包下的任意包中的UserService类或接口中所有名称为findById的方法
  execution(public User com..UserService.findById(..))
  ```

- `+`：专用于匹配子类类型

  ```java
  execution(* *..*Service+.*(..))
  ```

  

### 4.5.1 execution

在实际工作中使用较少，因为匹配配置不够灵活

`execution(public * com.elihe.service.*.*(..))` 基本能实现无差别全覆盖，即某个包下面的所有Bean的所有方法都会被拦截。

`execution(public * update*(..))` 从方法的前缀来区分，但容易误伤。

使用 AOP，可以将指定的方法装配到指定Bean的指定方法前后，如果自动装配时，因为不恰当的范围，容易导致意想不到的结果。



### 4.5.2 annotation

比 execution 更适用。

**Step 1**：定义注解

```java
package com.elihe.aop;

import java.lang.annotation.*;

@Target({ElementType.METHOD})
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface MsMetric {
    String value() default "";
}
```



**Step 2**：被监控的方法，加上注解

```java
package com.elihe.service;

import com.elihe.aop.MsMetric;
import org.springframework.stereotype.Component;

import java.util.concurrent.TimeUnit;

@Component
public class UserService {
    @MsMetric
    public void registerUser(String mail, String password, String nickname) {
        try {
            TimeUnit.SECONDS.sleep(3L);
        } catch (Exception e) {
            e.printStackTrace();
        }
        System.out.printf("mail: %s, password: %s, nickname: %s\n", mail, password, nickname);
    }
}
```



**Step 3**：性能监控AOP，切点使用annotation

```java
package com.elihe.aop;

import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Pointcut;
import org.springframework.stereotype.Component;

@Aspect
@Component
@Slf4j
public class MetricAspect {
    // 定义切点
    @Pointcut("@annotation(MsMetric)")
    public void pt() {}

    // 定义通知
    @Around("pt()")
    public Object doLogging(ProceedingJoinPoint pjp) throws Throwable {
        try {
            log.info("--------------------metric start--------------------");
            long startTime = System.currentTimeMillis();

            Object ret = pjp.proceed();

            long endTime = System.currentTimeMillis();
            log.info("方法执行时间：{}ms", endTime-startTime);
            log.info("--------------------metric end--------------------");
            return ret;
        } catch (Exception e) {
            log.error("异常信息", e);
            throw e;
        }
    }
}
```



**Step 4**：Spring配置

```java
package com.elihe.config;

import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.EnableAspectJAutoProxy;

@Configuration
@ComponentScan("com.elihe")
@EnableAspectJAutoProxy(proxyTargetClass = true)  // 开启AOP支撑，并设置代理为cglib
public class SpringConfig {
}
```



**Step 5**：主函数

```java
package com.elihe.learn;

import com.elihe.config.SpringConfig;
import com.elihe.service.UserService;
import org.springframework.context.ApplicationContext;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;

public class Main {
    public static void main(String[] args) {
        ApplicationContext context = new AnnotationConfigApplicationContext(SpringConfig.class);
        UserService userService = context.getBean(UserService.class);
        userService.registerUser("john@test.com", "123456", "john");
    }
}
```



## 4.6 AOP使用注意事项

- 访问被注入的 Bean 时，总是调用方法而非之间访问字段
- 编写Bean时，如果可能被代理，不用编写 `public final` 方法



# 5. ORM

示例表：

```sql
CREATE TABLE `user`  (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `name` varchar(30) CHARACTER SET utf8 COLLATE utf8_unicode_ci NULL DEFAULT NULL COMMENT '姓名',
  `age` int(11) NULL DEFAULT NULL COMMENT '年龄',
  `email` varchar(50) CHARACTER SET utf8 COLLATE utf8_unicode_ci NULL DEFAULT NULL COMMENT '邮箱',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 6 CHARACTER SET = utf8 COLLATE = utf8_unicode_ci ROW_FORMAT = Dynamic;


INSERT INTO `user`(`id`, `name`, `age`, `email`) VALUES (1, 'Sarah', 18, 'sarah@test.io');
INSERT INTO `user`(`id`, `name`, `age`, `email`) VALUES (2, 'Dianna', 20, 'dianna@test.io');
INSERT INTO `user`(`id`, `name`, `age`, `email`) VALUES (3, 'Smith', 28, 'smith@test.io');
INSERT INTO `user`(`id`, `name`, `age`, `email`) VALUES (4, 'Joe', 21, 'joe@test.io');
INSERT INTO `user`(`id`, `name`, `age`, `email`) VALUES (5, 'Tony', 24, 'tony@test.io');
```



## 5.1 JDBC

### 5.1.1 工程依赖

```xml
<dependencies>
    <dependency>
        <groupId>org.springframework</groupId>
        <artifactId>spring-context</artifactId>
        <version>5.2.16.RELEASE</version>
    </dependency>
    <dependency>
        <groupId>org.springframework</groupId>
        <artifactId>spring-jdbc</artifactId>
        <version>5.2.16.RELEASE</version>
    </dependency>
    <dependency>
        <groupId>javax.annotation</groupId>
        <artifactId>javax.annotation-api</artifactId>
        <version>1.3.2</version>
    </dependency>
    <dependency>
        <groupId>com.zaxxer</groupId>
        <artifactId>HikariCP</artifactId>
        <version>3.4.2</version>
    </dependency>
    <dependency>
        <groupId>mysql</groupId>
        <artifactId>mysql-connector-java</artifactId>
        <version>8.0.25</version>    
    </dependency>
   <dependency>
        <groupId>org.projectlombok</groupId>
        <artifactId>lombok</artifactId>
        <version>1.18.20</version>
    </dependency>
</dependencies>
```



### 5.1.2 JDBC 配置

将 DataSource 注入到 Spring

```java
package com.elihe.config;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

import javax.sql.DataSource;

@Configuration
public class JDBCConfig {
    @Bean
    public DataSource dataSource() {
        HikariConfig hikariConfig = new HikariConfig();
        hikariConfig.setUsername("root");
        hikariConfig.setPassword("123456");
        hikariConfig.setJdbcUrl("jdbc:mysql://192.168.3.102:3306/spring_db?serverTimezone=UTC");
        hikariConfig.setDriverClassName("com.mysql.cj.jdbc.Driver");
        hikariConfig.addDataSourceProperty("autoCommit", "true");
        hikariConfig.addDataSourceProperty("connectionTimeout", "5");
        hikariConfig.addDataSourceProperty("idleTimeout", "60");
        return new HikariDataSource(hikariConfig);
    }

    @Bean
    public JdbcTemplate jdbcTemplate(@Autowired DataSource dataSource) {
        return new JdbcTemplate(dataSource);
    }
}
```



### 5.1.3 用户类

```java
package com.elihe.domain;

import lombok.Data;

@Data
public class User {
    private Long id;

    private String name;

    private Integer age;

    private String email;
}
```



### 5.1.4 业务处理

```java
package com.elihe.service;

import com.elihe.domain.User;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.BeanPropertyRowMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Service;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

@Service
public class UserService {
    @Autowired
    private JdbcTemplate jdbcTemplate;

    public void save(String name, Integer age, String email) {
        KeyHolder holder = new GeneratedKeyHolder();
        int affected = jdbcTemplate.update((conn) -> {
            PreparedStatement ps = conn.prepareStatement("insert into user (name, age, email) values(?, ?, ?)",
                    Statement.RETURN_GENERATED_KEYS);
            ps.setObject(1, name);
            ps.setObject(2, age);
            ps.setObject(3, email);
            return ps;
        }, holder);

        if (affected > 0) {
            System.out.println("保存成功，user id: " + holder.getKey());
        }
    }

    public User getUser(Long id) {
        return jdbcTemplate.queryForObject("select * from user where id = ?",
                new Object[]{id}, new BeanPropertyRowMapper<>(User.class));
    }

    public List<User> getUserList(int page, int pageSize) {
        int index = (page-1)*pageSize;
        return jdbcTemplate.query("select * from user limit ?,?",
                new Object[]{index, pageSize}, new BeanPropertyRowMapper<>(User.class));
    }

    public boolean update(Long id, String name) {
        int affected = jdbcTemplate.update("update user set name=? where id=?", name, id);
        if (affected > 0) {
            return true;
        }

        throw new RuntimeException("update error");
    }

    public boolean delete(Long id) {
        int affected = jdbcTemplate.update("delete from user where id=?", id);
        return affected > 0;
    }

    public List<User> getUserListV1(int page, int pageSize) {
        return jdbcTemplate.execute("select * from user limit ?,?", (PreparedStatement ps) -> {
            ps.setObject(1, (page-1)*pageSize);
            ps.setObject(2, pageSize);

            List<User> users = new ArrayList<>();
            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                User user = new User();
                user.setId(rs.getLong("id"));
                user.setEmail(rs.getString("email"));
                user.setAge(rs.getInt("age"));
                user.setName(rs.getString("name"));

                users.add(user);
            }

            return users;
        });
    }

    public List<User> getUserListV2(int page, int pageSize) {
        return jdbcTemplate.execute((Connection conn) -> {
            PreparedStatement ps = conn.prepareStatement("select * from user limit ?,?");
            ps.setObject(1, (page-1)*pageSize);
            ps.setObject(2, pageSize);

            List<User> users = new ArrayList<>();
            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                User user = new User();
                user.setId(rs.getLong("id"));
                user.setEmail(rs.getString("email"));
                user.setAge(rs.getInt("age"));
                user.setName(rs.getString("name"));

                users.add(user);
            }

            return users;
        });
    }
}
```



### 5.1.5 Spring配置

```java
package com.elihe.config;

import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.Configuration;

@Configuration
@ComponentScan("com.elihe")
public class SpringConfig {
}
```



### 5.1.5 主函数

```java
package com.elihe.learn;

import com.elihe.config.SpringConfig;
import com.elihe.domain.User;
import com.elihe.service.UserService;
import org.springframework.context.ApplicationContext;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;

import java.util.List;

public class Main {
    public static void main(String[] args) {
        ApplicationContext context = new AnnotationConfigApplicationContext(SpringConfig.class);
        UserService userService = context.getBean(UserService.class);

        /*
        // 新增
        userService.save("eli", 29, "eli@luy.io");

        // 查询
        User user = userService.getUser(1L);
        System.out.println(user);

        // 分页查询
        List<User> users = userService.getUserList(1, 3);
        System.out.println(users);

        // 修改
        boolean updated = userService.update(3L, "Weixin");
        System.out.println(updated);

        // 删除
        boolean deleted = userService.delete(4L);
        System.out.println(deleted);
        */


        List<User> users1 = userService.getUserListV1(1, 5);
        System.out.println(users1);

        List<User> users2 = userService.getUserListV2(1, 5);
        System.out.println(users2);
    }
}
```



## 5.2 Mybatis

### 5.2.1 工程依赖

```xml
        <dependency>
            <groupId>org.mybatis</groupId>
            <artifactId>mybatis-spring</artifactId>
            <version>2.0.3</version>
        </dependency>
        <dependency>
            <groupId>org.mybatis</groupId>
            <artifactId>mybatis</artifactId>
            <version>3.5.3</version>
        </dependency>
        <dependency>
            <groupId>com.github.pagehelper</groupId>
            <artifactId>pagehelper</artifactId>
            <version>5.2.1</version>
        </dependency>
```



### 5.2.2 定义DataSource

**方式一**：通过 xml 配置，在 application.xml 中增加配置

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xmlns:context="http://www.springframework.org/schema/context"
       xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd http://www.springframework.org/schema/context https://www.springframework.org/schema/context/spring-context.xsd">

    <context:component-scan base-package="com.elihe" />

    <bean id="hikariConfig" class="com.zaxxer.hikari.HikariConfig">
        <property name="jdbcUrl" value="jdbc:mysql://192.168.3.102:3306/spring_db?characterEncoding=utf8&amp;serverTimezone=UTC" />
        <property name="driverClassName" value="com.mysql.cj.jdbc.Driver" />
        <property name="username" value="root" />
        <property name="password" value="123456" />
        <property name="autoCommit" value="true" />
        <property name="connectionTimeout" value="5000" />
        <property name="idleTimeout" value="60" />
    </bean>

    <bean id="dataSource" class="com.zaxxer.hikari.HikariDataSource">
        <constructor-arg name="configuration" ref="hikariConfig" />
    </bean>
    
    ...
</beans>
```



**方式二**：通过注解，JDBC配置

```java
package com.elihe.config;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import javax.sql.DataSource;

@Configuration
public class JdbcConfig {
    @Bean
    public DataSource dataSource() {
        HikariConfig hikariConfig = new HikariConfig();
        hikariConfig.setJdbcUrl("jdbc:mysql://192.168.3.102:3306/spring_db?serverTimezone=UTC");
        hikariConfig.setUsername("root");
        hikariConfig.setPassword("123456");
        hikariConfig.setDriverClassName("com.mysql.cj.jdbc.Driver");
        hikariConfig.addDataSourceProperty("autoCommit", "true");
        hikariConfig.addDataSourceProperty("connectionTimeout", "5");
        hikariConfig.addDataSourceProperty("idleTimeout", "60");
        return new HikariDataSource(hikariConfig);
    }
}
```



### 5.2.3 Mybatis 配置

定义SqlSessionFactoryBean和MapperScannerConfigurer



**方式一**：通过 xml 配置

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xmlns:context="http://www.springframework.org/schema/context"
       xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd http://www.springframework.org/schema/context https://www.springframework.org/schema/context/spring-context.xsd">

    <context:component-scan base-package="com.elihe" />
    ...
    
    <bean class="org.mybatis.spring.SqlSessionFactoryBean">
        <property name="dataSource" ref="dataSource" />
        <property name="mapperLocations" value="classpath*:mapper/*.xml" />
        <property name="plugins">
            <array>
                <bean class="com.github.pagehelper.PageInterceptor">
                    <property name="properties">
                        <props>
                            <prop key="helperDialect">mysql</prop>
                        </props>
                    </property>
                </bean>
            </array>
        </property>
    </bean>
    <bean class="org.mybatis.spring.mapper.MapperScannerConfigurer">
        <property name="basePackage" value="com.elihe.mapper" />
    </bean>
</beans>
```



**方式二**：通过注解配置

```java
package com.elihe.config;

import com.github.pagehelper.PageInterceptor;
import org.mybatis.spring.SqlSessionFactoryBean;
import org.mybatis.spring.mapper.MapperScannerConfigurer;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.Resource;
import org.springframework.core.io.support.PathMatchingResourcePatternResolver;
import org.springframework.core.io.support.ResourcePatternResolver;

import javax.sql.DataSource;
import java.io.IOException;
import java.util.Properties;

@Configuration
public class MybatisConfig {

    @Bean
    public SqlSessionFactoryBean sqlSessionFactoryBean(@Autowired DataSource dataSource) throws IOException {
        SqlSessionFactoryBean sqlSessionFactoryBean = new SqlSessionFactoryBean();
        sqlSessionFactoryBean.setDataSource(dataSource);

        ResourcePatternResolver resourcePatternResolver = new PathMatchingResourcePatternResolver();
        Resource[] resources = resourcePatternResolver.getResources("classpath*:mapper/*.xml");
        sqlSessionFactoryBean.setMapperLocations(resources);

        PageInterceptor pageInterceptor = new PageInterceptor();
        Properties properties = new Properties();
        properties.setProperty("helperDialect", "mysql");
        pageInterceptor.setProperties(properties);
        sqlSessionFactoryBean.setPlugins(pageInterceptor);

        return sqlSessionFactoryBean;
    }

    @Bean
    public MapperScannerConfigurer mapperScannerConfigurer() {
        MapperScannerConfigurer configurer = new MapperScannerConfigurer();
        configurer.setBasePackage("com.elihe.mapper");
        return configurer;
    }
}
```



### 5.2.4 用户类

```java
package com.elihe.domain;

import lombok.Data;

@Data
public class User {
    private Long id;

    private String name;

    private Integer age;

    private String email;
}
```



### 5.2.5 Mapper 接口和配置

**接口**：

```java
package com.elihe.mapper;

import com.elihe.domain.User;
import com.github.pagehelper.Page;

public interface UserMapper {
    int save(User user);

    int update(User user);

    User findById(Long id);

    Page<User> findAll();

    int delete(Long id);
}

```



**mapper**：resources/mapper/UserMapper.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE mapper
        PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN"
        "http://mybatis.org/dtd/mybatis-3-mapper.dtd">
<mapper namespace="com.elihe.mapper.UserMapper">

    <insert id="save" parameterType="com.elihe.domain.User" keyProperty="id" useGeneratedKeys="true">
        insert into user (name,age,email) values (#{name},#{age},#{email})
    </insert>
    <update id="update" parameterType="com.elihe.domain.User">
        update user
        <set>
            <if test="name != null and name.length > 0">
                name=#{name},
            </if>
            <if test="age != null">
                age=#{age},
            </if>
            <if test="email != null and email.length > 0">
                email=#{email}
            </if>
        </set>
        where id=#{id}
    </update>
    <delete id="delete" parameterType="long">
        delete from user where id=#{id}
    </delete>
    <select id="findById" parameterType="long" resultType="com.elihe.domain.User">
        select * from user where id=#{id}
    </select>
    <select id="findAll" resultType="com.elihe.domain.User">
        select * from user
    </select>
</mapper>
```



### 5.2.6 业务处理

```java
package com.elihe.service;

import com.elihe.domain.User;
import com.elihe.mapper.UserMapper;
import com.github.pagehelper.Page;
import com.github.pagehelper.PageHelper;
import com.github.pagehelper.PageInfo;
import org.springframework.stereotype.Service;

import javax.annotation.Resource;

@Service
public class UserService {
    @Resource
    private UserMapper userMapper;

    public void save(String name, Integer age, String email) {
        User user = new User();
        user.setName(name);
        user.setAge(age);
        user.setEmail(email);
        this.userMapper.save(user);
        System.out.println("新增成功，user id: " + user.getId());
    }

    public boolean update(Long id, String name) {
        User user = new User();
        user.setId(id);
        user.setName(name);
        return this.userMapper.update(user) > 0;
    }

    public boolean delete(Long id) {
        return this.userMapper.delete(id) > 0;
    }

    public User getUser(Long id) {
        return this.userMapper.findById(id);
    }

    public PageInfo<User> getUserList(int pageIndex, int pageSize) {
        PageHelper.startPage(pageIndex, pageSize);
        Page<User> userList = this.userMapper.findAll();
        return new PageInfo<>(userList);
    }
}
```



### 5.2.7 主函数

```java
package com.elihe.learn;

import com.elihe.config.SpringConfig;
import com.elihe.domain.User;
import com.elihe.service.UserService;
import com.github.pagehelper.PageInfo;
import org.springframework.context.ApplicationContext;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;

public class Main {
    public static void main(String[] args) {
//        ApplicationContext context = new ClassPathXmlApplicationContext("application.xml");
        ApplicationContext context = new AnnotationConfigApplicationContext(SpringConfig.class);
        UserService userService = context.getBean(UserService.class);

        userService.save("lucy", 32, "lucy@test.com");

        User user = userService.getUser(2L);
        System.out.println(user);

        boolean updated = userService.update(2L, "bob");
        System.out.println(updated);

        boolean deleted = userService.delete(5L);
        System.out.println(deleted);

        PageInfo<User> userList = userService.getUserList(1, 3);
        System.out.println(userList);
    }
}
```



### 5.2.8 Mapper SQL说明

- `#{}`：解析未一个**JDBC预编译语句**的参数标记符。将传入的参数当成一个字符串，会给传入的参数加一个双引号。很大程度上上防止sql注入；
- `${}`：仅仅一个**纯粹的string替换**，在动态SQL解析阶段将会进行变量替换。将传入的参数直接显示生成在sql中，不会添加引号。无法防止sql注入。



${}在预编译之前已经被变量替换了，存在sql注入的风险，如下：

```
select * from ${tableName} where name = ${name}1.
```



如果传入的参数tableName为user; delete user; --，那么sql动态解析之后，预编译之前的sql将变为：

```
select * from user; delete user; -- where name = ?;1.
```

`--`之后的语句将作为注释不起作用，顿时我和我的小伙伴惊呆了！！！看到没，本来的查询语句，竟然偷偷的包含了一个删除表数据的sql，是删除，删除，删除！！！重要的事情说三遍，可想而知，这个风险是有多大。



**总结：**

1. `${}`一般用于传输数据库的表名、字段名等
2. 能用`#{}`的地方尽量别用`${}`



**要实现动态调用表名和字段名，就不能使用预编译了**，需添加statementType="STATEMENT"

- STATEMENT：Statement，非预编译

- PREPARED：PreparedStatement，预编译，默认值

- CALLABLE中：CallableStatement

  

其次，sql里的变量取值是${xxx},不是#{xxx}。

因为`${}`是将传入的参数直接显示生成sql，如`${xxx}`传入的参数为字符串数据，需在参数传入前加上引号，如：

```
    String name = "sprite";
    name = "'" + name + "'";1.2.
```



## 5.3 事务

```sql
CREATE TABLE `user_bonus`  (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) NOT NULL,
  `bonus` int(11) NOT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8 COLLATE = utf8_unicode_ci ROW_FORMAT = Dynamic;
CREATE TABLE `user_gift`  (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) NOT NULL,
  `gift` tinyint(4) NOT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8 COLLATE = utf8_unicode_ci ROW_FORMAT = Dynamic;
```



### 5.3.1 基本概念

#### 5.3.1.1 ACID

- 原子性(Atomicity)  事务是一个不可分割的整体，其中的操作要么全成功或全失败
- 一致性(Consistency) 事务前后数据的完整性必须保持一致
- 隔离性(Isolation) 数据库为每一个用户开启的事务，不能被其他事务的操作数据干扰，多个并发事务之间要相互隔离
- 持久性(Durability) 一个事务一旦被提交，它对数据库中数据的改变就是永久性的



#### 5.3.1.2 隔离级别

- 脏读：运行读取未提交的信息
  - 原因：Read uncommitted (RU)
  - 解决方案：Read committed （表级读锁）RC
- 不可重复读：读取过程中单个数据发生了变化
  - 解决方案：Repeatable read （行级写锁）RR
- 幻读：读取过程中数据条目发生了变化
  - 解决方案：Serializable (表级写锁)

MySQL 默认隔离级别为 RR，但无幻读问题，使用了间隙锁+MVVC解决



### 5.3.2 Spring 事务

Spring 为业务层提供了整套的事务解决方案：

- PlatformTransactionManager 事务管理器
- TransactionDefinition 定义事务
- TransactionStatus 事务状态



#### 5.3.2.1 PlatformTransactionManager 

平台事务管理器实现类

- DataSourceTransactionManager 适用于 Spring JDBC 或 MyBatis
- HibernateTransactionManager 适用于 Hibernate3.0及以上
- JpaTransactionManager 适用于 JPA
- JdoTransactionManager 适用于 JDO
- JtaTransactionManager 适用于 JTA



此接口定义事务的基本操作：

- 获取事务

  ```java
  TransactionStatus getTransaction(TransactionDefinition definition)
  ```

- 提交事务

  ```java
  void commit(TransactionStatus status)
  ```

- 回滚事务

  ```java
  void rollback(TransactionStatus status)
  ```

  

#### 5.3.2.2 TransactionDefinition

此接口定义了事务的基本信息

- 获取事务定义名称

  ```java
  String getName()
  ```

- 获取事务的读写属性

  ```java
  boolean isReadOnly()
  ```

- 获取事务的隔离级别

  ```java
  int getIsolationLevel()
  ```

- 获取事务超时时间

  ```java
  int getTimeout()
  ```

- 货物事务传播行为特征

  ```java
  int getPropagationBehavior()
  ```



#### 5.3.2.3 TransactionStatus

此接口定了事务在执行过程中某个时间点上的状态信息及对应的状态操作

- 获取事务是否处于新开启事务状态

  ```java
  boolean isNewTransaction()
  ```

- 获取事务是否处于已完成状态

  ```java
  boolean isCompleted()
  ```

- 获取事务是否处于回滚状态

  ```java
  boolean isRollbackOnly()
  ```

- 刷新事务状态

  ```java
  void flush()
  ```

- 获取事务是否具有回滚存储点

  ```java
  boolean hasSavepoint()
  ```

- 设置事务处于回滚状态

  ```java
  void setRollbackOnly()
  ```



### 5.3.3 事务控制方式

- 编程式
- 声明式



#### 5.3.3.1 编程式

```java
package com.elihe.service;

import com.elihe.mapper.UserBonusMapper;
import com.elihe.mapper.UserGiftMapper;
import com.elihe.mapper.UserMapper;
import com.elihe.pojo.User;
import com.elihe.pojo.UserBonus;
import com.elihe.pojo.UserGift;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.TransactionStatus;
import org.springframework.transaction.support.DefaultTransactionDefinition;

import javax.annotation.Resource;
import javax.sql.DataSource;

@Service
public class UserService {
    @Resource
    private UserMapper userMapper;

    @Resource
    private UserBonusMapper userBonusMapper;

    @Resource
    private UserGiftMapper userGiftMapper;

    @Autowired
    private DataSource dataSource;

    public void register(String name, int age, String email) {
        // 支持事务
        PlatformTransactionManager ptm = new DataSourceTransactionManager(dataSource);
        TransactionDefinition td = new DefaultTransactionDefinition();
        TransactionStatus ts = ptm.getTransaction(td);

        try {
            User user = new User();
            user.setName(name);
            user.setAge(age);
            user.setEmail(email);
            this.userMapper.save(user);

            UserBonus userBonus = new UserBonus();
            userBonus.setUserId(user.getId());
            userBonus.setBonus(5);
            this.userBonusMapper.save(userBonus);

            int i = 1 /0;

            UserGift userGift = new UserGift();
            userGift.setUserId(user.getId());
            userGift.setGift(1); // 0-未发放 1-未领 2-已领
            this.userGiftMapper.save(userGift);

            // 提交事务
            ptm.commit(ts);
        } catch (Exception e) {
            e.printStackTrace();
            ptm.rollback(ts);
        }

    }
}
```



#### 5.3.3.2 声明式

```xml
        <dependency>
            <groupId>org.aspectj</groupId>
            <artifactId>aspectjweaver</artifactId>
            <version>1.9.7</version>
        </dependency>
```



##### 5.3.3.2.1 XML

```xml
 <!--定义事务管理的通知类-->
    <tx:advice id="txAdvice" transaction-manager="transactionManager">
        <!--定义控制的事务-->
        <tx:attributes>
            <tx:method
                    name="update*"
                    read-only="false"
                    timeout="-1"
                    isolation="DEFAULT"
                    no-rollback-for=""
                    rollback-for=""
                    propagation="REQUIRED"
            />
            <tx:method
                    name="save*"
                    read-only="false"
                    timeout="-1"
                    isolation="DEFAULT"
                    no-rollback-for=""
                    rollback-for=""
                    propagation="REQUIRED"
            />
        </tx:attributes>
    </tx:advice>

    <aop:aspectj-autoproxy proxy-target-class="true"/>
    <aop:config >
        <aop:pointcut id="pt" expression="execution(public * com..service.*.*(..))"/>
        <aop:advisor advice-ref="txAdvice" pointcut-ref="pt"/>
    </aop:config>
```



##### 5.3.3.2.2 注解

**@Transactional**

- 类型：方法注解、类注解、接口注解

- 位置：方法定义上方，类定义上方，接口定义上方

- 作用：设置当前类/接口中所有方法或具体方法开启事务，并指定相关事务属性

- 范例：

  ```java
  @Transactional(
      readOnly = false,
      timeout = -1,
      isolation = Isolation.DEFAULT,
      rollbackFor = {ArithmeticException.class, IOException.class},
      noRollbackFor = {},
      propagation = Propagation.REQUIRES_NEW
  )
  ```

  

tx:annotation-driven

- 类型：标签

- 归属：beans标签

- 作用：开启事务注解驱动，并指定对应的事务管理器

- 范例：

  ```xml
  <tx:annotation-driven transaction-manager="txManager"/>
  ```

  

@EnableTransactionManagement

- 类型：类注解

- 位置：Spring注解配置类上方

- 作用：开启注解驱动，等同XML格式中的注解驱动

- 范例：

  ```java
  @Configuration
  @EnableTransactionManagement
  public class SpringConfig {
  }
  ```

  

### 5.3.4 传播行为

- **REQUIRED**：如果存在一个事务，则支持当前事务；如果没有事务则开启一个新的事务。
- **REQUIRES_NEW**：它会开启一个新的事务。如果一个事务已经存在，则先将这个存在的事务挂起。
- **SUPPORTS**：如果存在一个事务，支持当前事务。如果没有事务，则非事务的执行。
- **NOT_SUPPORTED**：总是非事务地执行，并挂起任何存在的事务。
- **MANDATORY**：如果已经存在一个事务，支持当前事务。如果没有一个活动的事务，则抛出异常。
- **NEVER**：总是非事务地执行，如果存在一个活动事务，则抛出异常。
- **NESTED**：如果一个活动的事务存在，则运行在一个嵌套的事务中。如果没有活动事务，则按 TransactionDefinition.PROPAGATION_REQUIRED 属性执行。这是一个嵌套事务。



























