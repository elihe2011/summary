# 1. 创建工程



安装工具

```bash

npm install yarn -g

# 安装 vue-cli
npm install -g @vue/cli
npm install -g @vue/cli-init

vue --version
@vue/cli 5.0.8

# 创建项目
vue init webpack vue3-demo

# 启动
cd vue3-demo
npm run dev

# 图形化界面
vue ui
```



Vite 是一个 web 开发构建工具，由于其原生 ES 模块导入方式，可以实现闪电般的冷服务器启动。

使用vite创建工程：

```bash
npm init vite-app vue3-demo2

cd vue3-demo2
npm install
npm run dev
```



项目打包：

```bash
npm run build
```



创建项目：

```bash
vue create vue3-demo3
```



**v-once** 指令执行一次性地插值，当数据改变时，插值处的内容不会更新

**v-html** 指令用于输出 html 代码

**v-bind** 指令 HTML属性值绑定，对于布尔属性，常规值为 true 或 false，如果属性值为 null 或 undefined，则该属性不会显示出来

```vue
<div v-bind:id="dynamicId"></div>
<button v-bind:disabled="isButtonDisabled">按钮</button>
<div v-bind:class="{'class1': use}">
    
<!-- 完整语法 -->
<a v-bind:href="url"></a>
<!-- 缩写 -->
<a :href="url"></a>    
```

 

 **v-if** 指令根据表达式的值( true 或 false )来决定是否插入元素

```vue
 <p v-if="seen">现在你看到我了</p>

<div id="app">
    <div v-if="Math.random() > 0.5">
      随机数大于 0.5
    </div>
    <div v-else>
      随机数小于等于 0.5
    </div>
</div>

<div id="app">
    <div v-if="type === 'A'">
         A
    </div>
    <div v-else-if="type === 'B'">
      B
    </div>
    <div v-else-if="type === 'C'">
      C
    </div>
    <div v-else>
      Not A/B/C
    </div>
</div>
```



**v-show** 指令是 **v-if** 的别名

```vue
<h1 v-show="ok">Hello!</h1>
```





**v-for** 指令可以绑定数组的数据来渲染一个项目列表

```vue
    <li v-for="site in sites">
      {{ site }}
    </li>

<!-- 第二个参数为索引 -->
<li v-for="(site, index) in sites">
      {{ index }} -{{ site }}
    </li>

<!-- 对象迭代 -->
<li v-for="value in object">
    {{ value }}
    </li>

<!-- 第二个参数为key -->
<li v-for="(value, key) in object">
    {{ key }} : {{ value }}
    </li>

<!-- 第三个参数为index -->
<li v-for="(value, key, index) in object">
     {{ index }}. {{ key }} : {{ value }}
    </li>

<!-- 整数迭代 -->
<li v-for="n in 10">
     {{ n }}
    </li>
```



**v-on** 指令用于监听 DOM 事件

```vue
<!-- 完整语法 -->
<a v-on:click="doSomething"> ... </a>

<!-- 缩写 -->
<a @click="doSomething"> ... </a>

<!-- 动态参数的缩写 (2.6.0+) -->
<a @[event]="doSomething"> ... </a>

<!-- .prevent 修饰符告诉v-on指令对于触发的事件调用 event.preventDefault() -->
<form v-on:submit.prevent="onSubmit"></form>
```



**v-model** 指令来实现双向数据绑定，在 input、select、textarea、checkbox、radio 等表单控件元素上创建双向数据绑定，根据表单上的值，自动更新绑定的元素的值。

```vue
<div id="app">
    <p>{{ message }}</p>
    <input v-model="message">
</div>
```



组件

prop 是子组件用来接受父组件传递过来的数据的一个自定义属性。

父组件的数据需要通过 props 把数据传给子组件，子组件需要显式地用 props 选项声明 "prop"：

```vue
<div id="app">
  <site-name title="Google"></site-name>
  <site-name title="Runoob"></site-name>
  <site-name title="Taobao"></site-name>
</div>
 
<script>
const app = Vue.createApp({})
 
app.component('site-name', {
  props: ['title'],
  template: `<h4>{{ title }}</h4>`
})
 
app.mount('#app')
</script>
```



### 动态 Prop

类似于用 v-bind 绑定 HTML 特性到一个表达式，也可以用 v-bind 动态绑定 props 的值到父组件的数据中。每当父组件的数据变化时，该变化也会传导给子组件：

```vue
<div id="app">
  <site-info
    v-for="site in sites"
    :id="site.id"
    :title="site.title"
  ></site-info>
</div>
 
<script>
const Site = {
  data() {
    return {
      sites: [
        { id: 1, title: 'Google' },
        { id: 2, title: 'Runoob' },
        { id: 3, title: 'Taobao' }
      ]
    }
  }
}
 
const app = Vue.createApp(Site)
 
app.component('site-info', {
  props: ['id','title'],
  template: `<h4>{{ id }} - {{ title }}</h4>`
})
 
app.mount('#app')
</script>
```



### Prop 验证

组件可以为 props 指定验证要求。

为了定制 prop 的验证方式，你可以为 props 中的值提供一个带有验证需求的对象，而不是一个字符串数组。例如：

```
Vue.component('my-component', {
  props: {
    // 基础的类型检查 (`null` 和 `undefined` 会通过任何类型验证)
    propA: Number,
    // 多个可能的类型
    propB: [String, Number],
    // 必填的字符串
    propC: {
      type: String,
      required: true
    },
    // 带有默认值的数字
    propD: {
      type: Number,
      default: 100
    },
    // 带有默认值的对象
    propE: {
      type: Object,
      // 对象或数组默认值必须从一个工厂函数获取
      default: function () {
        return { message: 'hello' }
      }
    },
    // 自定义验证函数
    propF: {
      validator: function (value) {
        // 这个值必须匹配下列字符串中的一个
        return ['success', 'warning', 'danger'].indexOf(value) !== -1
      }
    }
  }
})
```

当 prop 验证失败的时候，(开发环境构建版本的) Vue 将会产生一个控制台的警告。

type 可以是下面原生构造器：

- `String`
- `Number`
- `Boolean`
- `Array`
- `Object`
- `Date`
- `Function`
- `Symbol`

type 也可以是一个自定义构造器，使用 instanceof 检测。



属性：

**computed**：计算属性在处理一些复杂逻辑

 computed 是基于它的依赖缓存，只有相关依赖发生改变时才会重新取值。

 methods ，在重新渲染的时候，函数总会重新调用执行。



```vue
<div id="app">
    <p>{{ message }}</p>
    <p>{{ reversedMessage }}</p>
    <p>{{ reversedMessage2() }}</p>
</div>

<script>
const app = Vue.createApp({
    data() {
        return {
            message: 'hello world!'
        }
    },
    computed: {
        reversedMessage: function() {
            return this.message.split('').reverse().join('')
        }
    },
    methods: {
        reversedMessage2: function() {
            return this.message.split('').reverse().join('')
        }
    }
})

app.mount('#app')
</script>
```

属性设置：

```vue
<script>
const app = Vue.createApp({
    data() {
        return {
            name: 'Google',
            url: 'https://www.google.com'
        }
    },
    computed: {
        site: {
            get: function() {
                return this.name + ' ' + this.url
            },
            set: function(newValue) {
                var arr = newValue.split(' ')
                this.name = arr[0]
                this.url = arr[arr.length - 1]
            }
        }
    }
})

vm = app.mount('#app')

document.write('name: ', vm.name);
document.write('<br>')
document.write('url: ', vm.url);

document.write('rewrite<br>')
vm.site = 'Baidu  https://www.baidu.com'

document.write('name: ', vm.name);
document.write('<br>')
document.write('url: ', vm.url);

</script>
```





**watch**：监听属性 ，可以通过它来响应数据的变化

```vue
<div id="app">
    米：<input type="text" v-model="meters" @focus="currentActiveField='meters'"></input>
    千米：<input type="text" v-model="kilometers" @focus="currentActiveField='kilometers'"></input>
</div>
<p id="info"></p>

<script>
const app = Vue.createApp({
    data() {
        return { 
            meters: 0,
            kilometers: 0
        }
    },
    watch: {
        meters: function(newValue, oldValue) {
            if (this.currentActiveField === 'meters') {
                this.meters = newValue
                this.kilometers = newValue / 1000
            }
        },
        kilometers: function(newValue, oldValue) {
            if (this.currentActiveField === 'kilometers') {
                this.meters = newValue * 1000
                this.kilometers = newValue
            }
        }
    }
})

vm = app.mount('#app')
vm.$watch('kilometers', function(nval, oval) {
    document.getElementById('info').innerHTML = '修改前的值：' + oval + '，修改后的值：' + nval;
})
</script>
```



异步加载中使用 watch

```vue
<div id="app">
    <p>
        输入一个问题，以 ? 好结尾输出答案：
        <input v-model="question" />
    </p>
    <p>{{ answer }}</p>
</div>

<script>
const app = Vue.createApp({
    data() {
        return { 
            question: '',
            answer: ''
        }
    },
    watch: {
        question: function(newQ, oldQ) {
            if (newQ.indexOf('?') > -1 || newQ.indexOf('？') > -1) {
                this.getAnswer()
            }
        }
    },
    methods: {
        getAnswer() {
            this.answer = '加载中...'
            axios.get('http://localhost:3000/answer').then(resp => {
                this.answer = resp.data.answer
            }).catch(error => {
                this.answer = '无法访问服务端'
            })
        }
    }
})

app.mount('#app')
```



样式绑定：v-bind 在处理 class 和 style 时， 表达式除了可以使用字符串之外，还可以是对象或数组。

- **v-bind:class** 

- **v-bind:style**



class 属性绑定：

```vue
<!-- isActive为true时，active样式生效 -->
<div :class="{'active': isActive}"></div>

<!-- class对象: classObject: {'active': true, 'text-danger': false} -->
<div class="static" :class="classObject"></div>

<!-- class数组：预先定义activeClass, errorClass样式 -->
<div class="static" :class="[activeClass, errorClass]"></div>
```



style属性绑定：

```vue
<!-- 预定义color和fontSize变量 -->
<div :style="{color: color, fontSize: fontSize}">内联样式</div>

<!-- style对象 -->
<div :style="styleOject">内联样式</div>

<!-- style数组 -->
<div :style="[styleObject1, styleObject2]">内联样式</div>
```



使用组件属性：**$attrs**支持获取组件属性

```vue
<div id="app">
    <test class="classA"></test>
</div>

<script>
const app = Vue.createApp({})

app.component('test', {
    template: `
        <h2 :class="$attrs.class">Hello World!</h2>
        <span>这是一个组件</span>
    `
})

app.mount('#app')
</script>
```



事件处理：

v-on 指令，缩写 @

```vue
<div id="app">
    <button @click="greet('Hello')">点我</button>
</div>

<script>
const app = Vue.createApp({
    data() {
        return {
            name: 'Jack'
        }
    },
    methods: {
        greet: function(msg, event) {
            alert(msg + ' ' + this.name + '!')
            if (event) {
                console.log(event)
                alert(event.target.tagName)
            }
        }
    }
})

app.mount('#app')
</script>
```





表单：

 v-model 指令在表单 `<input>`、`<textarea>` 及 `<select>` 等元素上创建双向数据绑定

- text 和 textarea 元素使用 `value` 属性和 `input` 事件；
- checkbox 和 radio 使用 `checked` 属性和 `change` 事件；
- select 字段将 `value` 作为属性并将 `change` 作为事件。



text & textarea:

```vue
<div id="app">
    <p>input输入:</p>
    <input v-model="message1" placeholder="单行文本输入...">
    <p>input消息: {{ message1 }}</p>
    <br/>
    
    <p>textarea输入:</p>
    <textarea v-model="message2" placeholder="多行文本输入..."></textarea>
    <p>textarea消息:</p>
    <textarea style="margin:0;padding:0;border:none;display:block;" v-model="message2"></textarea>
</div>

<script>
const app = Vue.createApp({
    data() {
        return { 
            message1: '',
            message2: ''
        }
    }
})

app.mount('#app')
</script>
```



checkbox:

```vue
<div id="app">
    <p>单个复选框:</p>
    <input type="checkbox" id="cb" v-model="checked">
    <label for="cb">{{ checked }}</label>
    
    <p>多个复选框:</p>
    <input type="checkbox" id="google" value="Google" v-model="checkedNames">
    <label for="google">Google</label>
    <input type="checkbox" id="baidu" value="Baidu" v-model="checkedNames">
    <label for="baidu">Baidu</label>
    <input type="checkbox" id="bing" value="Bing" v-model="checkedNames">
    <label for="bing">Bing</label>
    <br>
    
    <span>选择的值为：{{ checkedNames }}</span>
</div>

<script>
const app = Vue.createApp({
    data() {
        return { 
            checked: false,
            checkedNames: []
        }
    }
})

app.mount('#app')
</script>
```



radio:

```vue
<div id="app">
    <input type="radio" id="google" value="Google" v-model="picked">
    <label for="google">Google</label>
    <input type="radio" id="baidu" value="Baidu" v-model="picked">
    <label for="baidu">Baidu</label>
    <input type="radio" id="bing" value="Bing" v-model="picked">
    <label for="bing">Bing</label>
    <br>
    
    <span>选择的值为：{{ picked }}</span>
</div>

<script>
const app = Vue.createApp({
    data() {
        return { 
            picked: 'Baidu'
        }
    }
})

app.mount('#app')
</script>
```



select:

```vue
<div id="app">
    <select v-model="selected">
        <option v-for="site in sites" :value="site.url">{{ site.name }}</option>
    </select>
    <br>
    
    <span>选择的值为：{{ selected }}</span>
</div>

<script>
const app = Vue.createApp({
    data() {
        return { 
            selected: '',
            sites: [
                { name: '选择个网站', url: '' },
                { name: 'Google', url: 'https://www.google.com' },
                { name: 'Baidu', url: 'https://www.baidu.com' },
                { name: 'Bing', url: 'https://www.bing.com' }
            ]
        }
    }
})

app.mount('#app')
</script>
```



装饰器：

```vue
<!-- 不自动更新，直到输入enter键 -->
<input v-model.lazy="msg" >

<!-- 转化为为数字类型 -->
<input v-model.number="age" type="number">

<!-- 去除行首空格，中间多个空格合并为一个 -->
<input v-model.trim="msg">
```





路由：vue-router

**router-link** 组件创建链接

**router-view** 显示与 url 对应的组件



```vue
<div id="app">
    <h1>Hello Vue Router</h1>
    
    <p>
        <router-link to="/" replace>Home</router-link>&nbsp;&nbsp;
        <router-link to="/about" replace>About</router-link>
    </p>
    
    <router-view></router-view>
</div>

<script>
// 1. 定义组件
const home = { template: '<h2>Home Page</h2>' }
const about = { template: '<h2>About Page</h2>' }

// 2. 定义路由
const routes = [
    { path: '/', component: home },
    { path: '/about', component: about },
]

// 3. 创建路由实例
const router = VueRouter.createRouter({
    // 内部 history 实现
    history: VueRouter.createWebHashHistory(),
    routes
})

// 4. 创建并挂载根实例
const app = Vue.createApp({})
app.use(router)
app.mount('#app')
</script>
```





`router-link`常用属性：

- **to**：表示目标路由的链接。 当被点击后，内部会立刻把 to 的值传到 router.push()，所以这个值可以是一个字符串或者是描述目标位置的对象

```vue
<!-- 字符串 -->
<router-link to="home">Home</router-link>
<a href="home">Home</a>

<!-- 使用 v-bind 的 JS 表达式 -->
<router-link v-bind:to="'home'">Home</router-link>
<router-link :to="'home'">Home</router-link>
<router-link :to="{ path: 'home' }">Home</router-link>

<!-- 命名的路由 -->
<router-link :to="{ name: 'user', params: { userId: 123 }}">User</router-link>

<!-- 带查询参数，下面的结果为 /register?plan=private -->
<router-link :to="{ path: 'register', query: { plan: 'private' }}">Register</router-link>
```



- **replace**：点击时，调用 router.replace() 而不是 router.push()，导航后不会留下 history 记录

```vue
<router-link :to="{ path: '/abc'}" replace></router-link>
```

- **append**：在当前 (相对) 路径前添加其路径。例如，从 /a 导航到一个相对路径 b，如果没有配置 append，则路径为 /b，否则为 /a/b

```vue
<router-link :to="{ path: 'relative/path'}" append></router-link>
```

- **tag**：想要将 `<router-link>` 渲染成某种标签，例如 `<li>`。可使用 `tag` prop 类指定标签，同样它还是会监听点击，触发导航。

```vue
<router-link to="/foo" tag="li">foo</router-link>
<!-- 渲染结果 -->
<li>foo</li>
```

- **active-class**：链接激活时使用的 CSS 类名。

```vue
<style>
   ._active{
      background-color : red;
   }
</style>
<p>
   <router-link v-bind:to="{ path: '/route1'}" active-class="_active">Router Link 1</router-link>
   <router-link v-bind:to="{ path: '/route2'}" tag="span">Router Link 2</router-link>
</p>
```

- **exact-active-class**：配置当链接被精确匹配的时候应该激活的 class

```vue
<p>
   <router-link v-bind:to="{ path: '/route1'}" exact-active-class="_active">Router Link 1</router-link>
   <router-link v-bind:to="{ path: '/route2'}" tag="span">Router Link 2</router-link>
</p>
```

- **event**：声明可以用来触发导航的事件。可以是一个字符串或是一个包含字符串的数组。

```vue
<router-link v-bind:to="{ path: '/route1'}" event="mouseover">Router Link 1</router-link>
```





-----------------------

混入 (mixins)：定义了一部分可复用的方法或者计算属性。混入对象可以包含任意组件选项。当组件使用混入对象时，所有混入对象的选项将被混入该组件本身的选项。

```vue
<script>
const myMixin = {
    data() {
        return {
            message: 'hello',
            foo: 'mixin'
        }
    },
    created() {
        console.log('mixin对象钩子被调用')
    }
}

const app = Vue.createApp({
    mixins: [myMixin],
    data() {
        return {
            message: 'goodbye',
            bar: 'app'
        }
    },
    created() {
        document.write(JSON.stringify(this.$data))
        console.log('组件对象钩子被调用')
    }
})

app.mount('#app')
</script>
```



**全局混入**：全局注册混入对象。 一旦使用全局混入对象，将会影响到所有之后创建的 Vue 实例。使用恰当时，可以为自定义对象注入处理逻辑。

```vue
<script>
const app = Vue.createApp({
    myOption: 'hello'
})

app.mixin({
    created() {
        const myOption = this.$options.myOption;
        if (myOption) {
            document.write(myOption)
        }
    }
})

app.mount('#app')
</script>
```



-----------------

axios：一个基于promise用于浏览器和node.js的http客户端

GET 请求：

```vue
<script>
const app = Vue.createApp({
    data() {
        return {
            result: ''
        }
    },
    methods: {
        query() {
            axios
              .get('http://localhost:3000/user?id=123')
              .then(response => {this.result = response.data})
              .catch(function (error) {
                 console.log(error)
              })
        },
        query2() {
            axios
              .get('http://localhost:3000/user', {
                params: {
                    id: 456
                }
              }).then(response => {this.result = response.data})
              .catch(function (error) {
                 console.log(error)
              })
        }
    }
})

app.mount('#app')
</script>
```



POST请求：

```vue
<script>
const app = Vue.createApp({
    data() {
        return {
            username: '',
            password: '',
            result: ''
        }
    },
    methods: {
        login() {
            axios
              .post('http://localhost:3000/login', {username: this.username, password: this.password})
              .then(response => {this.result = response.data})
              .catch(function (error) {
                 console.log(error)
              })
        }
    }
})

app.mount('#app')
</script>
```



axios API:  `axios(config)`

```vue
<script>
const app = Vue.createApp({
    data() {
        return {
            username: '',
            password: '',
            result: ''
        }
    },
    methods: {
        login() {
            axios({
                method: 'post', 
                url: 'http://localhost:3000/login',
                data: {
                    username: this.username,
                    password: this.password
                } 
            }).then(response => {this.result = response.data})
              .catch(function (error) {
                 console.log(error)
              })
        }
    }
})

app.mount('#app')
</script>
```



请求方法别名：

```vue
axios.request(config)
axios.get(url[, config])
axios.delete(url[, config])
axios.head(url[, config])
axios.post(url[, data[, config]])
axios.put(url[, data[, config]])
axios.patch(url[, data[, config]])
```



并发请求处理：

```
axios.all(iterable)
axios.spread(callback)
```



创建实例：

```vue
axios.create([config])
const instance = axios.create({
  baseURL: 'https://localhost:3000/',
  timeout: 1000,
  headers: {'X-Custom-Header': 'foobar'}
});
```



实例方法：

```js
request(config)
get(url[, config])
delete(url[, config])
head(url[, config])
post(url[, data[, config]])
put(url[, data[, config]])
patch(url[, data[, config]])
```



请求配置项：

```js
{
  url: "/user",
  method: "get", // 默认是 get
  baseURL: "https://some-domain.com/api/",

  // 允许在向服务器发送前，修改请求数据（"PUT", "POST" 和 "PATCH"）
  // 后面数组中的函数必须返回一个字符串，或 ArrayBuffer，或 Stream
  transformRequest: [function (data) {
    // 对 data 进行任意转换处理

    return data;
  }],

  // 在传递给 then/catch 前，允许修改响应数据
  transformResponse: [function (data) {
    // 对 data 进行任意转换处理

    return data;
  }],

  // 自定义请求头
  headers: {"X-Requested-With": "XMLHttpRequest"},

  // 请求 URL 参数
  params: {
    ID: 12345
  },

  // 负责 params 序列化的函数
  paramsSerializer: function(params) {
    return Qs.stringify(params, {arrayFormat: "brackets"})
  },

  // 请求主体被发送的数据（"PUT", "POST", 和 "PATCH"）
  // 在没有设置 `transformRequest` 时，必须是以下类型之一：
  // - string, plain object, ArrayBuffer, ArrayBufferView, URLSearchParams
  // - 浏览器专属：FormData, File, Blob
  // - Node 专属： Stream
  data: {
    firstName: "Fred"
  },

  // 请求超时的毫秒数(0表示无超时时间)
  timeout: 1000,

  // 跨域请求时是否需要使用凭证
  withCredentials: false, // 默认的

  // 允许自定义处理请求，以使测试更轻松
  // 返回一个 promise 并应用一个有效的响应 (查阅 [response docs](#response-api)).
  adapter: function (config) {
    /* ... */
  },

  // 使用 HTTP 基础验证，并提供凭据
  // 这将设置一个 `Authorization` 头，覆写掉现有的任意使用 `headers` 设置的自定义 `Authorization`头
  auth: {
    username: "janedoe",
    password: "s00pers3cret"
  },

  // 服务器响应的数据类型，可以是 "arraybuffer", "blob", "document", "json", "text", "stream"
  responseType: "json", // 默认的

  // xsrf token 的值的cookie的名称
  xsrfCookieName: "XSRF-TOKEN", // default

  // 承载 xsrf token 的值的 HTTP 头的名称
  xsrfHeaderName: "X-XSRF-TOKEN", // 默认的

  // 允许为上传处理进度事件
  onUploadProgress: function (progressEvent) {
    // 对原生进度事件的处理
  },

  // 允许为下载处理进度事件
  onDownloadProgress: function (progressEvent) {
    // 对原生进度事件的处理
  },

  // 定义允许的响应内容的最大尺寸
  maxContentLength: 2000,

  // 定义对于给定的HTTP 响应状态码是 resolve 或 reject promise。如果 `validateStatus` 返回 `true` (或者设置为 `null` 或 `undefined`)，promise 将被 resolve; 否则，promise 将被 rejecte
  validateStatus: function (status) {
    return status >= 200 && status < 300; // 默认的
  },

  // 定义在 node.js 中 follow 的最大重定向数目
  // 如果设置为0，将不会 follow 任何重定向
  maxRedirects: 5, // 默认的

  // 自定义代理。`keepAlive` 默认没有启用
  httpAgent: new http.Agent({ keepAlive: true }),
  httpsAgent: new https.Agent({ keepAlive: true }),

  // 定义代理服务器的主机名称和端口
  proxy: {
    host: "127.0.0.1",
    port: 9000,
    auth: : {
      username: "mikeymike",
      password: "rapunz3l"
    }
  },

  // 指定用于取消请求的 cancel token
  cancelToken: new CancelToken(function (cancel) {
  
  })
}
```



响应结构：

```js
{
  // 服务器响应
  data: {},

  // HTTP 状态码
  status: 200,

  // HTTP 状态信息
  statusText: "OK",

  // 服务器响应头
  headers: {},

  // 请求配置信息
  config: {}
}
```



响应处理：

```js
axios.get("/user/12345")
  .then(function(response) {
    console.log(response.data);
    console.log(response.status);
    console.log(response.statusText);
    console.log(response.headers);
    console.log(response.config);
  });
```



配置默认值：

全局默认值：

```js
axios.defaults.baseURL = 'https://api.example.com';
axios.defaults.headers.common['Authorization'] = AUTH_TOKEN;
axios.defaults.headers.post['Content-Type'] = 'application/x-www-form-urlencoded';
```



实例默认值：

```js
// 创建实例时设置配置的默认值
var instance = axios.create({
  baseURL: 'https://api.example.com'
});

// 在实例已创建后修改默认值
instance.defaults.headers.common['Authorization'] = AUTH_TOKEN;
```





拦截器：



全局拦截器：

```js
// 请求拦截器
axios.interceptors.request.use(function (config) {
    return config;
  }, function (error) {
    return Promise.reject(error);
  });

// 响应拦截器
axios.interceptors.response.use(function (response) {
    return response;
  }, function (error) {
    return Promise.reject(error);
  });
```



移除拦截器：

```js
var myInterceptor = axios.interceptors.request.use(function () {/*...*/});
axios.interceptors.request.eject(myInterceptor);
```





实例拦截器：

```js
var instance = axios.create();
instance.interceptors.request.use(function () {/*...*/});
```

