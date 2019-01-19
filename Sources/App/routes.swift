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
    router.get("maps", "json", Int.parameter, use: gameMapController.json)
    router.get("maps", "random", use: gameMapController.random)
    router.get("maps", "seed", String.parameter, use: gameMapController.withSeed)
    //router.delete("maps", GameMap.parameter, use: gameMapController.delete)
}
