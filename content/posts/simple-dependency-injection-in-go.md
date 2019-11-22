+++
title = "Simple dependency injection in Go with Fx"
date = "2019-11-21"
author = "Yage Hu"
cover = ""
tags = ["go", "fx"]
keywords = ["go", "golang"]
description = '''Learn how Fx makes dependency injection and developing
applications simple in Go.
'''
showFullContent = false
+++

At Uber, it is a breeze to scaffold new Go applications. A simple-to-use
dependency injection framework called [Fx](https://github.com/uber-go/fx) makes
this possible. I will briefly discuss why you may want to use dependency
injection in your Go application, introduce the Fx framework, and present an
example application that takes advantage of Fx.

# Why you may want to use dependency injection in Go?

What is dependency injection (DI)? From a great quote I found in a Stack
Overflow answer:

> "Dependency Injection" is a 25-dollar term for a 5-cent concept, [...]
> Dependency injection means giving an object its instance variables. [...]

Simply put, DI is the technique of providing the dependencies that an object
needs. There are tons of resource on the internet about DI that explains the
concept better than I will, so I'll keep it concise by demonstrating one of the
most important benefits of using DI: it makes testing dramatically easier.

Consider the following function that queries a SQL database and returns the
result.

```go
func query() (email string) {
    db, err := sql.Open("postgres", "user=postgres dbname=test ...")
    if err != nil {
        panic(err)
    }
    err = db.QueryRow(`SELECT email FROM "user" WHERE id = $1`, 1).Scan(&email)
    if err != nil {
        panic(err)
    }
    return email
}
```

This function does not use DI. The function constructs its dependency—the
database handle `*sql.DB`—instead of accepting it as an input. This makes unit
testing it a problem. How can we mock the database? DI solves the testability
problem. The following code uses DI and can be tested much easier.

```go
func query(db *sql.DB) (email string) {
    err = db.QueryRow(`SELECT email FROM "user" WHERE id = $1`, 1).Scan(&email)
    if err != nil {
        panic(err)
    }
    return email
}

func TestQuery(t *testing.T) {
    db := mockDB()
    defer db.Close()

    email := query(db)
    assert.Equal(t, email, "email@example.com")
}
```

The same testability improvement applies not only to database connections, but
also to any custom structs you may define. If you define interfaces for your
domain-specific entities, your functions can accept interfaces, allowing mocks
to be provided to the functions during test time.

# Introducting Fx: a Go dependency injection framework.

[Fx](github.com/uber-go/fx) is Uber's solution for easy DI in Go. According to
[Fx's GoDoc](https://godoc.org/go.uber.org/fx):

> Package fx is a framework that makes it easy to build applications out of
> reusable, composable modules.

Many gophers will read this and convulse. Surely we don't want to bring Spring
and all its complexities to Go, a language that emphasizes simplicity and
maintainability. My goal is to show you that Fx is lightweight and easy to
learn. This section presents the few types and functions that Fx exposes.

All Fx applications start with an `fx.App` that can be constructed from
`fx.New()`. A minimal Fx app that does nothing can be initialized and run with:

```go
func main() {
    fx.New().Run()
}
```

Fx has the concept of lifecycle for its applications. Lifecycle allows you to
register functions that will be executed at application's start and stop time. A
common use case is to register handler function for routes.

```go
func main() {
    fx.New(
        fx.Invoke(register),
    ).Run()
}

func register(lifecycle fx.Lifecycle) {
    mux := http.NewServeMux()
    server := http.Server{
        Addr: ":8080",
        Handler mux,
    }
    mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
    })

    lifecycle.Append(
        fx.Hook{
            OnStart: func(context.Context) error {
                go server.ListenAndServe()
                return nil
            },
            OnStop: func(ctx context.Context) error {
                return server.Shutdown(ctx)
            }
        }
    )
}
```

In the previous example, you get a taste of Fx's DI capability. `register` is
invoked by the app using `fx.Invoke()`. Upon app start, lifecycle will be
automatically provided to `register` as a parameter. This example will start a
HTTP server using Go's standard library.

You can also provide arbitrary custom object constructors to the Fx app.

```go
func newObject() *object {
    return &object{}
}

func main() {
    fx.New(
        fx.Provide(newObject),
        fx.Invoke(doStuff),
    ).Run()
}

func doStuff(obj *object) {
    // Do stuff with obj
}
```

Fx provide many other advanced DI features. Its GoDoc provides example usage.

# An example modular Fx application.

I've created a [sample Fx app](github.com/yagehu/sample-fx-app) that runs an HTTP server.
