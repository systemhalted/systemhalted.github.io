---
layout: post
title: "Java Generics: The Cost of Type Erasure"
category:
- Computer Science
tags:
- computer-science
- java
- type-erasure
- programming-language
comments: true
toc: true
description: Generic types in Java are excellent for compile-time safety, but weak as runtime type descriptors. Whenever a framework crosses a runtime boundary such as JSON, reflection, dependency injection, messaging, persistence, or RPC, it often needs an explicit replacement for the erased generic type information.
---

This post is not an introduction to Java generics. I am assuming you are already familiar with the topic. The core idea I want to capture in this post is that Java checks generic types at compile time but erases much of that information at runtime, and that this changes how code behaves. This runtime behavior is known as type erasure, which means `List<String>` and `List<Integer>` both become `List` at runtime.

This behavior causes some interesting bugs and awkward APIs. We will explore some of them in this post.

## 1. `List<String>.class` does not exist

We are all familiar with `List.class`, `String.class`, `Integer.class` but `List<String>.class` is an illegal construct in Java. At runtime, Java does not have a separate class object for `List<String>` versus `List<Integer>`.

That is why APIs that often accept this `Class<T> type` break down for generic types.

For example, this API looks clean:

```java
<T> T read(String json, Class<T> type)
```

It works well for a normal object:

```java
User user = read(json, User.class);
```

However, the following will be impossible:

```java
List<User> users = read(json, List<User>.class);
```
There is no `List<User>.class` to pass. You may be tempted to make it work by trying:

```java
List<User> users = read(json, List.class);
```
But now the runtime only knows that the target type is `List`. It does not know that the list is supposed to contain `User` objects.

This is where bugs begin. A JSON library, for example, may deserialize the JSON array into a `List<LinkedHashMap>` instead of a `List<User>`. The code may compile, but fail later when you try to use one of the elements as a `User`.

```java
List<User> users = read(json, List.class); 

User user = users.get(0); // may fail at runtime
```

The problem is not that the list may be empty. That would be a normal collection issue. The type erasure problem is that even if the list contains elements, those elements may not be of the type the source code appears to promise.

To solve this, libraries invented alternate ways to carry generic type information into runtime APIs.

Jackson uses `TypeReference<T>`:

```java
List<User> users = objectMapper.readValue(json, new TypeReference<List<User>>() {});
```

Gson uses `TypeToken<T>`:

```java
List<User> users =
    gson.fromJson(json, new TypeToken<List<User>>() {}.getType());
```

Spring uses `ParameterizedTypeReference<T>`:

```java
ResponseEntity<List<User>> response =
    restTemplate.exchange(
        url,
        HttpMethod.GET,
        null,
        new ParameterizedTypeReference<List<User>>() {}
    );
```

These APIs look awkward because they are working around the same missing runtime concept: a class-like object that represents a fully parameterized generic type. If Java supported class literals for parameterized types such as `List<User>.class`, many of these APIs could have been simpler.

## 2. `instanceof List<String>` does not work

Another place where type erasure shows up is runtime type checking. In Java, we commonly use `instanceof` to check the type of an object.

```java
if (obj instanceof String) {
...
}
```

But Java won't let you write

```java
if (obj instanceof List<String>) {
 ...
}
```

The reason is that `List<String>` is not fully available at runtime. After type erasure, the runtime can check whether the `obj` is a `List`, but it cannot directly check whether it is specifically a `List<String>`.

So, Java only allows this:

```java
if (obj instanceof List<?>) {
...
}
```
This tells us that `obj` is some kind of `List`. It does not tell us what kind of elements the list contains and we must inspect each element individually, if we really care:

```java
if (obj instanceof List<?> list &&
    list.stream().allMatch(String.class::isInstance)) { //this check returns true for an empty list as well
     ...
}
```
This works, but it is much more verbose than a normal runtime type check. It also changes the nature of the check. We are no longer asking the JVM, “Is this a `List<String>`?” We are asking, “Is this a `List`, and do all of its current elements happen to be strings?”

## 3. Method overloads can clash after erasure

Java lets you overload methods when their parameters are different. For example, this is fine:

```java
void process(String name) {...}

void process(Integer id) {...}
```
At runtime these are still different. However, with generics, method overloading gets a little tricky. 

You may think that this will work:

```java
void process(List<String> names) {...}

void process(List<Integer> ids) {...}
```

But Java rejects this because after type erasure both effectively are the same method:
```
void process(List names) {...}
void process(List ids) {...}
```

Both have the same erased signature `void process(List)`. The compiler sees the method collision and throws this error:

```
name clash: process(List<Integer>) and process(List<String>) have the same erasure
```

The workaround usually is to give methods different names `processNames(List<String> names)` and `processIds(List<Integer> ids)`.

Another option is to introduce wrapper types:

```java
record Names(List<String> names) {}
record Ids(List<Integer> ids) {}

void process(Names names) {...}

void process(Ids ids) {...}
```
This works because `Names` and `Ids` are real runtime types. They survive erasure, unlike `List<String>` and `List<Integer>`.

## 4. Generic arrays are painful

Type erasure also makes arrays and generics uncomfortable together.

In Java, arrays know their component type at runtime. For example, a `String[]` knows that it is an array of `String`. If you try to put an `Integer` into it, the JVM can detect the problem and throw an `ArrayStoreException`.

```java
String[] names = new String[10];
Object[] values = names;

values[0] = 42; // ArrayStoreException at runtime
```

Generics work differently. A `List<String>` does not carry `String` as a full runtime type in the same way. After erasure, it is mostly just a `List`.

That mismatch is why Java does not allow this:

```java
T[] values = new T[10]; // illegal
```

The runtime does not know what `T` really is, so it cannot create an array with the correct component type.

The workaround is to pass the component type explicitly:

```java
static <T> T[] createArray(Class<T> type, int size) {
    return (T[]) java.lang.reflect.Array.newInstance(type, size);
}
```

Usage:

```java
String[] names = createArray(String.class, 10);
Integer[] ids = createArray(Integer.class, 10);
```

The generic type `T` is known to the compiler, but not enough is available at runtime. So the API asks the caller to pass a `Class<T>` token manually.

This is another cost of type erasure. The type appears obvious in the source code, but runtime code still needs an explicit type descriptor to do the right thing.

## Why these workarounds work

Type erasure is not total. Java still records generic type information in the class file, in a metadata section called the `Signature` attribute. This is kept for declarations: fields, method parameters and return types, and a class's generic superclass and interfaces. What gets erased is the type of a value at runtime. A `List<String>` object and a `List<Integer>` object share the same `List.class`, so an object cannot tell you its element type. But a declaration can.

That retained information is readable through reflection. `Field.getGenericType()`, `Method.getGenericReturnType()`, and `Class.getGenericSuperclass()` return a `java.lang.reflect.Type`, which can be a `ParameterizedType` such as `List<User>` rather than a plain `List`.

This is the trick behind `TypeReference`, `TypeToken`, and `ParameterizedTypeReference`. Writing `new TypeReference<List<User>>() {}` creates an anonymous subclass, and its generic superclass `TypeReference<List<User>>` is a declaration. So `List<User>` is preserved in that subclass's metadata, and the library recovers it with `getClass().getGenericSuperclass()`:

```java
Type type = new TypeReference<List<User>>() {}
    .getClass()
    .getGenericSuperclass(); // ParameterizedType: List<User>
```

## Conclusion

Once your code crosses a runtime boundary, assume the generic type will not be there. Design the API to carry the type explicitly, through a `Class<T>` token, a `TypeReference<T>`, a wrapper type, or a type tag you store in the data yourself, rather than trusting that the compiler's view of the type survives into runtime.
