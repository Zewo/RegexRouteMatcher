@testable import RegexRouteMatcher
import XCTest

class RegexRouteMatcherTests: XCTestCase {
    let ok = BasicResponder { request in
        return Response(status: .ok)
    }

    func testRegexRouteMatcherMatchesRoutes() {
        testMatcherMatchesRoutes(RegexRouteMatcher.self)
    }

    func testRegexRouteMatcherWithTrailingSlashes() {
        testMatcherWithTrailingSlashes(RegexRouteMatcher.self)
    }

    func testRegexRouteMatcherParsesPathParameters() {
        testMatcherParsesPathParameters(RegexRouteMatcher.self)
    }

    func testRegexRouteMatcherMatchesWildstars() {
        testMatcherMatchesWildstars(RegexRouteMatcher.self)
    }

    func testPerformanceOfRegexRouteMatcher() {
        #if os(OSX)
            measure {
                self.testPerformanceOfMatcher(RegexRouteMatcher.self)
            }
        #endif
    }

    func testMatcherMatchesRoutes(_ matcher: RouteMatcher.Type) {
        let routes: [Route] = [
            TestRoute(path: "/hello/world"),
            TestRoute(path: "/hello/dan"),
            TestRoute(path: "/api/:version"),
            TestRoute(path: "/servers/json"),
            TestRoute(path: "/servers/:host/logs")
        ]

        let matcher = matcher.init(routes: routes)

        func route(_ path: String, shouldMatch: Bool) -> Bool {
            let request = try! Request(method: .get, uri: path)
            let matched = matcher.match(request)
            return shouldMatch ?  matched != nil : matched == nil
        }

        XCTAssert(route("/hello/world", shouldMatch: true))
        XCTAssert(route("/hello/dan", shouldMatch: true))
        XCTAssert(route("/hello/world/dan", shouldMatch: false))
        XCTAssert(route("/api/v1", shouldMatch: true))
        XCTAssert(route("/api/v2", shouldMatch: true))
        XCTAssert(route("/api/v1/v1", shouldMatch: false))
        XCTAssert(route("/api/api", shouldMatch: true))
        XCTAssert(route("/servers/json", shouldMatch: true))
        XCTAssert(route("/servers/notjson", shouldMatch: false))
        XCTAssert(route("/servers/notjson/logs", shouldMatch: true))
        XCTAssert(route("/servers/json/logs", shouldMatch: true))
    }

    func testMatcherWithTrailingSlashes(_ matcher: RouteMatcher.Type) {
        let routes: [Route] = [
            TestRoute(path: "/hello/world")
        ]

        let matcher = matcher.init(routes: routes)

        let request1 = try! Request(method: .get, uri: "/hello/world")
        let request2 = try! Request(method: .get, uri: "/hello/world/")

        XCTAssert(matcher.match(request1) != nil)
        XCTAssert(matcher.match(request2) != nil)
    }

    func testMatcherParsesPathParameters(_ matcher: RouteMatcher.Type) {

        let routes: [Route] = [
            TestRoute(
                path: "/hello/world",
                actions: [
                    .get: BasicResponder { _ in
                        Response(body: "hello world - not!")
                    }
                ]
            ),
            TestRoute(
                path: "/hello/:location",
                actions: [
                    .get: BasicResponder {
                        Response(body: "hello \($0.pathParameters["location"]!)")
                    }
                ]
            ),
            TestRoute(
                path: "/:greeting/:location",
                actions: [
                    .get: BasicResponder {
                        Response(body: "\($0.pathParameters["greeting"]!) \($0.pathParameters["location"]!)")
                    }
                ]
            )
        ]

        let matcher = matcher.init(routes: routes)

        func body(_ request: Request, _ expectedResponse: String) -> Bool {
            guard var body = try? matcher.match(request)?.respond(to: request).body else {
                return false
            }
            guard let buffer = try? body?.becomeBuffer() else {
                return false
            }
            return buffer == expectedResponse.data
        }

        let helloWorld = try! Request(method: .get, uri: "/hello/world")
        let helloAmerica = try! Request(method: .get, uri: "/hello/america")
        let heyAustralia = try! Request(method: .get, uri: "/hey/australia")

        XCTAssert(body(helloWorld, "hello world - not!"))
        XCTAssert(body(helloAmerica, "hello america"))
        XCTAssert(body(heyAustralia, "hey australia"))
    }

    func testMatcherMatchesWildstars(_ matcher: RouteMatcher.Type) {

        func testRoute(path: String, response: String) -> Route {
            return TestRoute(path: path, actions: [.get: BasicResponder { _ in Response(body: response) }])
        }

        let routes: [Route] = [
            testRoute(path: "/*", response: "wild"),
            testRoute(path: "/hello/*", response: "hello wild"),
            testRoute(path: "/hello/dan", response: "hello dan"),
        ]

        let matcher = matcher.init(routes: routes)

        func route(_ path: String, expectedResponse: String) -> Bool {
            let request = try! Request(method: .get, uri: path)
            let matched = matcher.match(request)

            guard var body = try? matched?.respond(to: request).body else {
                return false
            }
            guard let buffer = try? body?.becomeBuffer() else {
                return false
            }
            return buffer == expectedResponse.data
        }

        XCTAssert(route("/a/s/d/f", expectedResponse: "wild"))
        XCTAssert(route("/hello/asdf", expectedResponse: "hello wild"))
        XCTAssert(route("/hello/dan", expectedResponse: "hello dan"))
    }

    func testPerformanceOfMatcher(_ matcher: RouteMatcher.Type) {
        let routePairs: [(HTTP.Method, String)] = [
            // Objects
            (.post, "/1/classes/:className"),
            (.get, "/1/classes/:className/:objectId"),
            (.put, "/1/classes/:className/:objectId"),
            (.get, "/1/classes/:className"),
            (.delete, "/1/classes/:className/:objectId"),

            // Users
            (.post, "/1/users"),
            (.get, "/1/login"),
            (.get, "/1/users/:objectId"),
            (.put, "/1/users/:objectId"),
            (.get, "/1/users"),
            (.delete, "/1/users/:objectId"),
            (.post, "/1/requestPasswordReset"),

            // Roles
            (.post, "/1/roles"),
            (.get, "/1/roles/:objectId"),
            (.put, "/1/roles/:objectId"),
            (.get, "/1/roles"),
            (.delete, "/1/roles/:objectId"),

            // Files
            (.post, "/1/files/:fileName"),

            // Analytics
            (.post, "/1/events/:eventName"),

            // Push Notifications
            (.post, "/1/push"),

            // Installations
            (.post, "/1/installations"),
            (.get, "/1/installations/:objectId"),
            (.put, "/1/installations/:objectId"),
            (.get, "/1/installations"),
            (.delete, "/1/installations/:objectId"),

            // Cloud Functions
            (.post, "/1/functions"),
        ]

        let requestPairs: [(HTTP.Method, String)] = [
            // Objects
            (.post, "/1/classes/test"),
            (.get, "/1/classes/test/test"),
            (.put, "/1/classes/test/test"),
            (.get, "/1/classes/test"),
            (.delete, "/1/classes/test/test"),

            // Users
            (.post, "/1/users"),
            (.get, "/1/login"),
            (.get, "/1/users/test"),
            (.put, "/1/users/test"),
            (.get, "/1/users"),
            (.delete, "/1/users/test"),
            (.post, "/1/requestPasswordReset"),

            // Roles
            (.post, "/1/roles"),
            (.get, "/1/roles/test"),
            (.put, "/1/roles/test"),
            (.get, "/1/roles"),
            (.delete, "/1/roles/test"),

            // Files
            (.post, "/1/files/test"),

            // Analytics
            (.post, "/1/events/test"),

            // Push Notifications
            (.post, "/1/push"),

            // Installations
            (.post, "/1/installations"),
            (.get, "/1/installations/test"),
            (.put, "/1/installations/test"),
            (.get, "/1/installations"),
            (.delete, "/1/installations/test"),

            // Cloud Functions
            (.post, "/1/functions"),
        ]

        let routes: [Route] = routePairs.map {
            TestRoute(
                path: $0.1,
                actions: [$0.0: ok]
            )
        }

        let requests = requestPairs.map {
            Request(method: $0.0, uri: URI(path: $0.1))
        }

        let matcher = matcher.init(routes: routes)

        for _ in 0...50 {
            for request in requests {
                matcher.match(request)
            }
        }
    }
}

struct TestRoute: Route {
    let path: String
    let actions: [HTTP.Method: Responder]

    init(path: String, actions: [HTTP.Method: Responder] = [:]) {
        self.path = path
        self.actions = actions
    }
}

extension RegexRouteMatcherTests {
    static var allTests: [(String, RegexRouteMatcherTests -> () throws -> Void)] {
        return [
           ("testRegexRouteMatcherMatchesRoutes", testRegexRouteMatcherMatchesRoutes),
        ]
    }
}
