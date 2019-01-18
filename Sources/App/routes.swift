import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    // Basic "It works" example
    router.get { req in
        return "It works!"
    }
    
    // Basic "Hello, world!" example
    router.get("hello") { req in
        return "Hello, world!"
    }

    let gameMapController = MapsController()
    router.get("maps", use: gameMapController.index)
    router.get("maps", "random", use: gameMapController.random)
    router.post("maps", use: gameMapController.create)
    router.delete("maps", GameMap.parameter, use: gameMapController.delete)
}
