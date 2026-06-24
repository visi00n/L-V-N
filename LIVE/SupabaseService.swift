//
//  SupabaseService.swift
//  LIVE
//
//  Created by Codex on 6/23/26.
//

import Foundation
import Supabase

let supabase = SupabaseClient(
    supabaseURL: LiveConfig.supabaseURL,
    supabaseKey: LiveConfig.supabasePublishableKey
)
