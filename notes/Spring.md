# 1. Spring

Spring是一个支持快速开发Java EE应用程序的框架。它提供了一系列底层容器和基础设施，并可以和大量常用的开源框架无缝集成，可以说是开发Java EE应用程序的必备。

Spring Framework主要包括几个模块：

- 支持IoC和AOP的容器；
- 支持JDBC和ORM的数据访问模块；
- 支持声明式事务的模块；
- 支持基于Servlet的MVC开发；
- 支持基于Reactive的Web开发；
- 以及集成JMS、JavaMail、JMX、缓存等其他模块。



## 1.1 IoC 容器

Spring的核心就是提供了一个IoC容器，它可以管理所有轻量级的JavaBean组件，提供的底层服务包括组件的生命周期管理、配置和组装服务、AOP支持，以及建立在AOP基础上的声明式事务服务等。



### 1.1.1 IoC 原理

IoC，Inversion of Control，控制反转

IoC又称为依赖注入（DI：Dependency Injection），它解决了一个最主要的问题：将组件的创建+配置与组件的使用相分离，并且，由IoC容器负责管理组件的生命周期。

因为IoC容器要负责实例化所有的组件，因此，有必要告诉容器如何创建组件，以及各组件的依赖关系。一种最简单的配置是通过XML文件来实现。

```xml
<beans>
    <bean id="dataSource" class="HikariDataSource" />
    <bean id="bookService" class="BookService">
        <property name="dataSource" ref="dataSource" />
    </bean>
    <bean id="userService" class="UserService">
        <property name="dataSource" ref="dataSource" />
    </bean>
</beans>
```

- 依赖注入

  依赖注入可以通过 set() 方法实现。也可以通过构造方法实现：

  ```java
  public class BookService {
      private DataSource dataSource;
  
      public void setDataSource(DataSource dataSource) {
          this.dataSource = dataSource;
      }
  }
  
  public class BookService {
      private DataSource dataSource;
      
      public BookService(DataSource dataSource) {
          this.dataSource = dataSource
      }
  }
  ```

  Spring 的 IoC 容器同时支持属性注入和构造方法注入，并允许混合使用

- 无侵入容器

  无侵入，是指应用程序的组件无需实现Spring的特定接口



### 1.1.2 装配Bean















# 1. Spring Cloud

## 1.1 概念

Spring Cloud 是一系列框架的有序集合。它利用 Spring Boot 的开发便利性，巧妙地简化了分布式系统基础设施的开发，如服务注册、服务发现、配置中心、消息总线、负载均衡、断路器、数据监控等，这些都可以用 Spring Boot 的开发风格做到一键启动和部署。

Spring Cloud 就是用于构建微服务开发和治理的框架集合（并不是具体的一个框架），主要贡献来自 Netflix OSS。



## 1.2 组件

- Eureka：服务注册中心，用于服务管理。
- Ribbon：基于客户端的负载均衡组件。
- Hystrix：容错框架，能够防止服务的雪崩效应。
- Feign：Web 服务客户端，能够简化 HTTP 接口的调用。
- Zuul：API 网关，提供路由转发、请求过滤等功能。
- Config：分布式配置管理。
- Sleuth：服务跟踪。
- Stream：构建消息驱动的微服务应用程序的框架。
- Bus：消息代理的集群消息总线。



# 2. Spring Boot

Spring Boot 是由 Pivotal 团队提供的全新框架，其设计目的是简化新 Spring 应用的初始搭建以及开发过程。该框架使用了特定的方式进行配置，从而使开发人员不再需要定义样板化的配置。

- 基于 Spring 开发 Web 应用更加容易。
- 采用基于注解方式的配置，避免了编写大量重复的 XML 配置。
- 可以轻松集成 Spring 家族的其他框架，比如 Spring JDBC、Spring Data 等。
- 提供嵌入式服务器，令开发和部署都变得非常方便。



# pringboot和springcloud区别

[Z, ZLW](https://worktile.com/kb/user/26) 11个月前 9600

> **springboot和springcloud区别**有：1、含义不同；2、作用不同；3、使用方式不同；4、特征不同；5、注释不同；6、优势不同；7、组件不同；8、设计目的不同。其中，含义不同指的是springboot是一个快速开发框架，而SpringCloud是建立在SpringBoot上的服务框架。

## 1、含义不同

**springboot**：一个快速开发框架，它简化了传统MVC的XML配置，使配置变得更加方便、简洁。

**springcloud**：是建立在SpringBoot上的服务框架，进一步简化了配置，它整合了一全套简单、便捷且通俗易用的框架。

## 2、作用不同

**springboot**：为了提供一个默认配置，从而简化配置过程。

**springcloud**：为了给微服务提供一个综合管理框架。

## 3、使用方式不同

**springboot**：可以单独使用。

**springcloud**：springcloud必须在springboot使用的前提下才能使用。

## 4、特征不同

**springboot**：

- **spring应用：**通过调用静态 run（） 方法创建独立的 Spring 应用程序。
- **Web应用程序：**我们可以使用嵌入式Tomcat，Jetty或Undertow创建HTTP服务器。无需部署 WAR 文件。
- **外化配置：**弹簧启动也提供基于产品的应用程序。它在不同的环境中也同样有效。
- **安全性：**它是安全的，内置于所有HTTP端点的基本身份验证中。
- **应用程序事件和监听器：**Spring Boot必须处理许多任务，应用程序所需的事件。添加用于创建工厂文件的侦听器。

**springcloud**：

- **智能路由和服务发现：**在创建微服务时，有四个服务很重要。服务发现就是其中之一。这些服务相互依赖。
- **服务到服务调用：**要连接所有具有序列的从属服务，请注册以调用终端节点。
- **负载均衡：**将网络流量适当分配到后端服务器。
- **领导选举：**应用程序作为第三方系统与另一个应用程序一起使用。
- **全局锁定：**两个线程不能同时访问同一资源。
- **分布式配置和分布式消息传递**

## 5、注释不同

**springboot**：

- **@SpringBootApplication：**此注释可以找到每个spring引导应用程序。它由三个注释组成：@EnableAutoConfiguration；@Configuration；@ComponentScan。它允许执行Web应用程序而无需部署到任何Web服务器中。
- **@EnableAutoConfiguration：**要么您使用的是低于1.1的spring boot版本，要么是@SpringBootApplication没有使用，那么需要此注释。
-  **@ContextConfiguration：**JUnit测试需要它。spring-boot 应用程序需要单元测试来测试其中的服务类。它加载SpringBoot上下文，但未提供完整的SpringBoot处理。
- **@SpringApplicationConfiguration：**它具有相同的工作@ContextConfiguration但提供完整的springboot处理。它加载 Bean 以及启用日志记录并从 application.properties 文件
- 加载属性。**@ConditionalOnBoot：**它定义了几个条件注释：@ConditionalOnMissingBoot；@ConditionalOnClass；@ConditionalOnMissingClass；@ConditionalOnExpression；@ConditionalOnJav。

**springcloud**：Spring Cloud主要遵循5个主要注释：

- **@EnableConfigServer：**此注释将应用程序转换为服务器，该服务器更多地用于应用程序以获取其配置。
- **@EnableEurekaServer：**用于 Eureka Discovery Services 的此注释可用于查找使用它的服务。
- **@EnableDiscoveryClient：**帮助此注释应用程序在服务发现中注册，发现使用它的其他服务。
- **@EnableCircuitBreaker：**使用断路器模式在相关服务发生故障时继续运行，防止级联故障。此注释主要用于 Hystrix 断路器。
- **@HystrixCommand（回退方法=“ fallbackMethodName”）：**用于标记回退到另一种方法的方法，它们无法正常成功。

## 6、优势不同

**springboot**：

- 快速开发和运行独立的弹簧Web应用程序。
- 默认情况下，它在需要时配置Spring功能。它的豆子被初始化并自动连接。
- 它不需要基于 XML 的配置。直接嵌入Tomcat，Jetty以避免复杂的部署。
- 没有必要部署 WAR 文件。

**springcloud**：

- 提供云服务开发。
- 它是基于微服务的架构来配置。
- 它提供服务间通信。
- it 基于Spring Boot模型。

## 7、组件不同

**springboot**：spring启动启动器，spring启动自动配置，spring启动执行器，spring启动 CLI，spring启动初始化。

**springcloud**：配置、服务发现、断路器、路由和消息传递、API 网关、跟踪、CI 管道和测试。

## 8、设计目的不同

**springboot**：springboot的设计目的是为了在微服务开发过程中可以简化配置文件，提高工作效率。

**springcloud**：springcloud的设计目的是为了管理同一项目中的各项微服务，因此二者是完全不同的两个软件开发框架





# Z. IntelliJ IDEA

- 非maven项目
  在 src 目录上点右键，选择 Mark Directory As -> Sources Root
- maven项目
  - 右键 /src/main/java目录，选择 Mark Directory As -> Sources Root
  - 右键 /src/test目录，选择 Mark Directory As -> Test Sources Root
  - 右键 pom.xml文件，选择 Add As a Maven Project
  - 右键 pom.xml文件，选择 Maven>reimport
