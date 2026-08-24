//
//  ImageLoader.swift
//  SwiftListExample
//
//  Created by Dan on 2026/08/24.
//

import UIKit

final class ImageLoader {
   private static let cache = NSCache<NSURL, UIImage>()

   static func cached(_ url: URL) -> UIImage? {
	  cache.object(forKey: url as NSURL)
   }

   static func load(_ url: URL) async -> UIImage? {
	  if let image = cached(url) { return image }
	  do {
		 let (data, _) = try await URLSession.shared.data(from: url)
		 guard let image = UIImage(data: data) else { return nil }
		 cache.setObject(image, forKey: url as NSURL)
		 return image
	  } catch {
		 return nil
	  }
   }
}
