export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      accommodation_amenities: {
        Row: {
          accommodation_id: string
          amenity: Database["public"]["Enums"]["amenity"]
        }
        Insert: {
          accommodation_id: string
          amenity: Database["public"]["Enums"]["amenity"]
        }
        Update: {
          accommodation_id?: string
          amenity?: Database["public"]["Enums"]["amenity"]
        }
        Relationships: [
          {
            foreignKeyName: "accommodation_amenities_accommodation_id_fkey"
            columns: ["accommodation_id"]
            isOneToOne: false
            referencedRelation: "accommodations"
            referencedColumns: ["id"]
          },
        ]
      }
      accommodation_documents: {
        Row: {
          accommodation_id: string
          doc_type: string
          expires_at: string | null
          file_sha256: string | null
          file_url: string
          id: string
          issued_at: string | null
          uploaded_at: string
          version: number
        }
        Insert: {
          accommodation_id: string
          doc_type: string
          expires_at?: string | null
          file_sha256?: string | null
          file_url: string
          id?: string
          issued_at?: string | null
          uploaded_at?: string
          version?: number
        }
        Update: {
          accommodation_id?: string
          doc_type?: string
          expires_at?: string | null
          file_sha256?: string | null
          file_url?: string
          id?: string
          issued_at?: string | null
          uploaded_at?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "accommodation_documents_accommodation_id_fkey"
            columns: ["accommodation_id"]
            isOneToOne: false
            referencedRelation: "accommodations"
            referencedColumns: ["id"]
          },
        ]
      }
      accommodation_facilities: {
        Row: {
          access_scope: string
          accommodation_id: string
          description: string | null
          facility_type: string
          floor: number | null
          id: string
          label: string | null
          room_id: string | null
          sort_order: number
          status: string
        }
        Insert: {
          access_scope: string
          accommodation_id: string
          description?: string | null
          facility_type: string
          floor?: number | null
          id?: string
          label?: string | null
          room_id?: string | null
          sort_order?: number
          status?: string
        }
        Update: {
          access_scope?: string
          accommodation_id?: string
          description?: string | null
          facility_type?: string
          floor?: number | null
          id?: string
          label?: string | null
          room_id?: string | null
          sort_order?: number
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "accommodation_facilities_accommodation_id_fkey"
            columns: ["accommodation_id"]
            isOneToOne: false
            referencedRelation: "accommodations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "accommodation_facilities_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "rooms"
            referencedColumns: ["id"]
          },
        ]
      }
      accommodation_facility_images: {
        Row: {
          facility_id: string
          id: string
          sort_order: number
          url: string
        }
        Insert: {
          facility_id: string
          id?: string
          sort_order?: number
          url: string
        }
        Update: {
          facility_id?: string
          id?: string
          sort_order?: number
          url?: string
        }
        Relationships: [
          {
            foreignKeyName: "accommodation_facility_images_facility_id_fkey"
            columns: ["facility_id"]
            isOneToOne: false
            referencedRelation: "accommodation_facilities"
            referencedColumns: ["id"]
          },
        ]
      }
      accommodation_facility_rooms: {
        Row: {
          facility_id: string
          room_id: string
        }
        Insert: {
          facility_id: string
          room_id: string
        }
        Update: {
          facility_id?: string
          room_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "accommodation_facility_rooms_facility_id_fkey"
            columns: ["facility_id"]
            isOneToOne: false
            referencedRelation: "accommodation_facilities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "accommodation_facility_rooms_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "rooms"
            referencedColumns: ["id"]
          },
        ]
      }
      accommodation_floors: {
        Row: {
          accommodation_id: string
          created_at: string
          floor_number: number
          label: string | null
        }
        Insert: {
          accommodation_id: string
          created_at?: string
          floor_number: number
          label?: string | null
        }
        Update: {
          accommodation_id?: string
          created_at?: string
          floor_number?: number
          label?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "accommodation_floors_accommodation_id_fkey"
            columns: ["accommodation_id"]
            isOneToOne: false
            referencedRelation: "accommodations"
            referencedColumns: ["id"]
          },
        ]
      }
      accommodation_images: {
        Row: {
          accommodation_id: string
          id: string
          sort_order: number | null
          url: string
        }
        Insert: {
          accommodation_id: string
          id?: string
          sort_order?: number | null
          url: string
        }
        Update: {
          accommodation_id?: string
          id?: string
          sort_order?: number | null
          url?: string
        }
        Relationships: [
          {
            foreignKeyName: "accommodation_images_accommodation_id_fkey"
            columns: ["accommodation_id"]
            isOneToOne: false
            referencedRelation: "accommodations"
            referencedColumns: ["id"]
          },
        ]
      }
      accommodation_policies: {
        Row: {
          accommodation_id: string
          advance_months: number | null
          contract_type: string | null
          cooking: boolean | null
          curfew_time: string | null
          deposit_months: number | null
          house_rules_json: Json | null
          laundry: boolean | null
          min_stay: number | null
          pets: boolean | null
          quiet_hours: string | null
          visitor_policy: string | null
        }
        Insert: {
          accommodation_id: string
          advance_months?: number | null
          contract_type?: string | null
          cooking?: boolean | null
          curfew_time?: string | null
          deposit_months?: number | null
          house_rules_json?: Json | null
          laundry?: boolean | null
          min_stay?: number | null
          pets?: boolean | null
          quiet_hours?: string | null
          visitor_policy?: string | null
        }
        Update: {
          accommodation_id?: string
          advance_months?: number | null
          contract_type?: string | null
          cooking?: boolean | null
          curfew_time?: string | null
          deposit_months?: number | null
          house_rules_json?: Json | null
          laundry?: boolean | null
          min_stay?: number | null
          pets?: boolean | null
          quiet_hours?: string | null
          visitor_policy?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "accommodation_policies_accommodation_id_fkey"
            columns: ["accommodation_id"]
            isOneToOne: true
            referencedRelation: "accommodations"
            referencedColumns: ["id"]
          },
        ]
      }
      accommodation_reviews: {
        Row: {
          accommodation_id: string
          comment: string | null
          created_at: string
          id: string
          lease_id: string
          rating: number
          student_id: string
        }
        Insert: {
          accommodation_id: string
          comment?: string | null
          created_at?: string
          id?: string
          lease_id: string
          rating: number
          student_id: string
        }
        Update: {
          accommodation_id?: string
          comment?: string | null
          created_at?: string
          id?: string
          lease_id?: string
          rating?: number
          student_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "accommodation_reviews_accommodation_id_fkey"
            columns: ["accommodation_id"]
            isOneToOne: false
            referencedRelation: "accommodations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "accommodation_reviews_lease_id_fkey"
            columns: ["lease_id"]
            isOneToOne: true
            referencedRelation: "leases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "accommodation_reviews_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "accommodation_reviews_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      accommodations: {
        Row: {
          accommodation_type: string | null
          accreditation_expires_at: string | null
          accreditation_status: string | null
          accredited_at: string | null
          address: string | null
          appeal_used: boolean
          barangay: string | null
          business_name: string | null
          capacity: number | null
          city: string | null
          created_at: string
          description: string | null
          draft_reminded_at: string | null
          gender_policy: string | null
          hidden_from_listings: boolean
          id: string
          landlord_id: string
          lat: number | null
          lng: number | null
          name: string
          purok: string | null
          rating_avg: number | null
          reviewing_at: string | null
          reviewing_by: string | null
          reviews_count: number | null
          room_type: Database["public"]["Enums"]["room_type"] | null
          status: Database["public"]["Enums"]["accommodation_status"]
          total_floors: number | null
          total_rooms: number | null
        }
        Insert: {
          accommodation_type?: string | null
          accreditation_expires_at?: string | null
          accreditation_status?: string | null
          accredited_at?: string | null
          address?: string | null
          appeal_used?: boolean
          barangay?: string | null
          business_name?: string | null
          capacity?: number | null
          city?: string | null
          created_at?: string
          description?: string | null
          draft_reminded_at?: string | null
          gender_policy?: string | null
          hidden_from_listings?: boolean
          id?: string
          landlord_id: string
          lat?: number | null
          lng?: number | null
          name: string
          purok?: string | null
          rating_avg?: number | null
          reviewing_at?: string | null
          reviewing_by?: string | null
          reviews_count?: number | null
          room_type?: Database["public"]["Enums"]["room_type"] | null
          status: Database["public"]["Enums"]["accommodation_status"]
          total_floors?: number | null
          total_rooms?: number | null
        }
        Update: {
          accommodation_type?: string | null
          accreditation_expires_at?: string | null
          accreditation_status?: string | null
          accredited_at?: string | null
          address?: string | null
          appeal_used?: boolean
          barangay?: string | null
          business_name?: string | null
          capacity?: number | null
          city?: string | null
          created_at?: string
          description?: string | null
          draft_reminded_at?: string | null
          gender_policy?: string | null
          hidden_from_listings?: boolean
          id?: string
          landlord_id?: string
          lat?: number | null
          lng?: number | null
          name?: string
          purok?: string | null
          rating_avg?: number | null
          reviewing_at?: string | null
          reviewing_by?: string | null
          reviews_count?: number | null
          room_type?: Database["public"]["Enums"]["room_type"] | null
          status?: Database["public"]["Enums"]["accommodation_status"]
          total_floors?: number | null
          total_rooms?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "accommodations_landlord_id_fkey"
            columns: ["landlord_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "accommodations_landlord_id_fkey"
            columns: ["landlord_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "accommodations_reviewing_by_fkey"
            columns: ["reviewing_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "accommodations_reviewing_by_fkey"
            columns: ["reviewing_by"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      account_notes: {
        Row: {
          author_id: string | null
          body: string
          created_at: string
          id: string
          user_id: string
        }
        Insert: {
          author_id?: string | null
          body: string
          created_at?: string
          id?: string
          user_id: string
        }
        Update: {
          author_id?: string | null
          body?: string
          created_at?: string
          id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "account_notes_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "account_notes_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "account_notes_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "account_notes_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      account_standing: {
        Row: {
          reason: string | null
          restrictions: string[]
          suspended_until: string | null
          updated_at: string
          updated_by: string | null
          user_id: string
        }
        Insert: {
          reason?: string | null
          restrictions?: string[]
          suspended_until?: string | null
          updated_at?: string
          updated_by?: string | null
          user_id: string
        }
        Update: {
          reason?: string | null
          restrictions?: string[]
          suspended_until?: string | null
          updated_at?: string
          updated_by?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "account_standing_updated_by_fkey"
            columns: ["updated_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "account_standing_updated_by_fkey"
            columns: ["updated_by"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "account_standing_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "account_standing_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      accreditation_rounds: {
        Row: {
          accommodation_id: string
          decided_at: string | null
          decided_by: string | null
          decision: string | null
          flagged_docs: string[] | null
          id: string
          kind: string
          message: string | null
          note: string | null
          proposed_changes: Json | null
          round: number
          submitted_at: string
          submitted_by: string | null
          tags: string[] | null
        }
        Insert: {
          accommodation_id: string
          decided_at?: string | null
          decided_by?: string | null
          decision?: string | null
          flagged_docs?: string[] | null
          id?: string
          kind: string
          message?: string | null
          note?: string | null
          proposed_changes?: Json | null
          round: number
          submitted_at?: string
          submitted_by?: string | null
          tags?: string[] | null
        }
        Update: {
          accommodation_id?: string
          decided_at?: string | null
          decided_by?: string | null
          decision?: string | null
          flagged_docs?: string[] | null
          id?: string
          kind?: string
          message?: string | null
          note?: string | null
          proposed_changes?: Json | null
          round?: number
          submitted_at?: string
          submitted_by?: string | null
          tags?: string[] | null
        }
        Relationships: [
          {
            foreignKeyName: "accreditation_rounds_accommodation_id_fkey"
            columns: ["accommodation_id"]
            isOneToOne: false
            referencedRelation: "accommodations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "accreditation_rounds_decided_by_fkey"
            columns: ["decided_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "accreditation_rounds_decided_by_fkey"
            columns: ["decided_by"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "accreditation_rounds_submitted_by_fkey"
            columns: ["submitted_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "accreditation_rounds_submitted_by_fkey"
            columns: ["submitted_by"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      admin_access: {
        Row: {
          expires_at: string | null
          granted_by: string | null
          levels: Json
          preset: string
          updated_at: string
          user_id: string
        }
        Insert: {
          expires_at?: string | null
          granted_by?: string | null
          levels?: Json
          preset?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          expires_at?: string | null
          granted_by?: string | null
          levels?: Json
          preset?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "admin_access_granted_by_fkey"
            columns: ["granted_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admin_access_granted_by_fkey"
            columns: ["granted_by"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admin_access_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admin_access_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      admin_profiles: {
        Row: {
          employee_id: string | null
          office: Database["public"]["Enums"]["office"]
          position: string | null
          user_id: string
        }
        Insert: {
          employee_id?: string | null
          office: Database["public"]["Enums"]["office"]
          position?: string | null
          user_id: string
        }
        Update: {
          employee_id?: string | null
          office?: Database["public"]["Enums"]["office"]
          position?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "admin_profiles_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admin_profiles_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      announcements: {
        Row: {
          accommodation_id: string | null
          archived: boolean
          audience: Database["public"]["Enums"]["audience_type"]
          author_id: string
          body: string
          deadline_at: string | null
          event_at: string | null
          event_end: string | null
          expires_at: string | null
          id: string
          image_url: string | null
          location: string | null
          notified_at: string | null
          published_at: string | null
          summary: string | null
          title: string
        }
        Insert: {
          accommodation_id?: string | null
          archived?: boolean
          audience?: Database["public"]["Enums"]["audience_type"]
          author_id: string
          body: string
          deadline_at?: string | null
          event_at?: string | null
          event_end?: string | null
          expires_at?: string | null
          id?: string
          image_url?: string | null
          location?: string | null
          notified_at?: string | null
          published_at?: string | null
          summary?: string | null
          title: string
        }
        Update: {
          accommodation_id?: string | null
          archived?: boolean
          audience?: Database["public"]["Enums"]["audience_type"]
          author_id?: string
          body?: string
          deadline_at?: string | null
          event_at?: string | null
          event_end?: string | null
          expires_at?: string | null
          id?: string
          image_url?: string | null
          location?: string | null
          notified_at?: string | null
          published_at?: string | null
          summary?: string | null
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "announcements_accommodation_id_fkey"
            columns: ["accommodation_id"]
            isOneToOne: false
            referencedRelation: "accommodations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "announcements_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "announcements_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      app_release: {
        Row: {
          apk_url: string
          bundle_checksum: string | null
          bundle_url: string | null
          bundle_version: number | null
          id: number
          latest_version_code: number
          latest_version_name: string
          min_supported_version_code: number
          release_notes: string | null
          updated_at: string
        }
        Insert: {
          apk_url: string
          bundle_checksum?: string | null
          bundle_url?: string | null
          bundle_version?: number | null
          id?: number
          latest_version_code: number
          latest_version_name: string
          min_supported_version_code?: number
          release_notes?: string | null
          updated_at?: string
        }
        Update: {
          apk_url?: string
          bundle_checksum?: string | null
          bundle_url?: string | null
          bundle_version?: number | null
          id?: number
          latest_version_code?: number
          latest_version_name?: string
          min_supported_version_code?: number
          release_notes?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      audit_logs: {
        Row: {
          action: string
          actor_id: string | null
          after_json: Json | null
          before_json: Json | null
          created_at: string
          entity_id: string
          entity_type: string
          id: string
          ip_address: string | null
          user_agent: string | null
        }
        Insert: {
          action: string
          actor_id?: string | null
          after_json?: Json | null
          before_json?: Json | null
          created_at?: string
          entity_id: string
          entity_type: string
          id?: string
          ip_address?: string | null
          user_agent?: string | null
        }
        Update: {
          action?: string
          actor_id?: string | null
          after_json?: Json | null
          before_json?: Json | null
          created_at?: string
          entity_id?: string
          entity_type?: string
          id?: string
          ip_address?: string | null
          user_agent?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "audit_logs_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "audit_logs_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      boarding_history: {
        Row: {
          accommodation_id: string
          accommodation_name: string | null
          end_reason: string | null
          id: string
          period_end: string
          period_start: string
          room_type: string | null
          student_id: string
        }
        Insert: {
          accommodation_id: string
          accommodation_name?: string | null
          end_reason?: string | null
          id?: string
          period_end: string
          period_start: string
          room_type?: string | null
          student_id: string
        }
        Update: {
          accommodation_id?: string
          accommodation_name?: string | null
          end_reason?: string | null
          id?: string
          period_end?: string
          period_start?: string
          room_type?: string | null
          student_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "boarding_history_accommodation_id_fkey"
            columns: ["accommodation_id"]
            isOneToOne: false
            referencedRelation: "accommodations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boarding_history_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boarding_history_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      concerns: {
        Row: {
          acknowledged_at: string | null
          category: string
          created_at: string
          description: string | null
          id: string
          in_progress_at: string | null
          lease_id: string
          manager_response: string | null
          photo_url: string | null
          reported_at: string
          resolved_at: string | null
          status: string
          updated_at: string
        }
        Insert: {
          acknowledged_at?: string | null
          category: string
          created_at?: string
          description?: string | null
          id?: string
          in_progress_at?: string | null
          lease_id: string
          manager_response?: string | null
          photo_url?: string | null
          reported_at?: string
          resolved_at?: string | null
          status?: string
          updated_at?: string
        }
        Update: {
          acknowledged_at?: string | null
          category?: string
          created_at?: string
          description?: string | null
          id?: string
          in_progress_at?: string | null
          lease_id?: string
          manager_response?: string | null
          photo_url?: string | null
          reported_at?: string
          resolved_at?: string | null
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "concerns_lease_id_fkey"
            columns: ["lease_id"]
            isOneToOne: false
            referencedRelation: "leases"
            referencedColumns: ["id"]
          },
        ]
      }
      conversations: {
        Row: {
          id: string
          inquiry_room_id: string | null
          invited_at: string | null
          invited_room_id: string | null
          last_message: string | null
          last_sender_id: string | null
          last_time: string | null
          unread_a: number
          unread_b: number
          user_a_id: string
          user_b_id: string
        }
        Insert: {
          id?: string
          inquiry_room_id?: string | null
          invited_at?: string | null
          invited_room_id?: string | null
          last_message?: string | null
          last_sender_id?: string | null
          last_time?: string | null
          unread_a?: number
          unread_b?: number
          user_a_id: string
          user_b_id: string
        }
        Update: {
          id?: string
          inquiry_room_id?: string | null
          invited_at?: string | null
          invited_room_id?: string | null
          last_message?: string | null
          last_sender_id?: string | null
          last_time?: string | null
          unread_a?: number
          unread_b?: number
          user_a_id?: string
          user_b_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "conversations_inquiry_room_id_fkey"
            columns: ["inquiry_room_id"]
            isOneToOne: false
            referencedRelation: "rooms"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "conversations_invited_room_id_fkey"
            columns: ["invited_room_id"]
            isOneToOne: false
            referencedRelation: "rooms"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "conversations_last_sender_id_fkey"
            columns: ["last_sender_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "conversations_last_sender_id_fkey"
            columns: ["last_sender_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "conversations_user_a_id_fkey"
            columns: ["user_a_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "conversations_user_a_id_fkey"
            columns: ["user_a_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "conversations_user_b_id_fkey"
            columns: ["user_b_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "conversations_user_b_id_fkey"
            columns: ["user_b_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      expiry_reminders: {
        Row: {
          accommodation_id: string
          days_before: number
          due_date: string
          sent_at: string
          subject: string
        }
        Insert: {
          accommodation_id: string
          days_before: number
          due_date: string
          sent_at?: string
          subject: string
        }
        Update: {
          accommodation_id?: string
          days_before?: number
          due_date?: string
          sent_at?: string
          subject?: string
        }
        Relationships: [
          {
            foreignKeyName: "expiry_reminders_accommodation_id_fkey"
            columns: ["accommodation_id"]
            isOneToOne: false
            referencedRelation: "accommodations"
            referencedColumns: ["id"]
          },
        ]
      }
      landlord_payout: {
        Row: {
          bank_account_name: string | null
          bank_account_number: string | null
          bank_name: string | null
          gcash_name: string | null
          gcash_number: string | null
          landlord_id: string
          maya_name: string | null
          maya_number: string | null
          note: string | null
          updated_at: string
        }
        Insert: {
          bank_account_name?: string | null
          bank_account_number?: string | null
          bank_name?: string | null
          gcash_name?: string | null
          gcash_number?: string | null
          landlord_id: string
          maya_name?: string | null
          maya_number?: string | null
          note?: string | null
          updated_at?: string
        }
        Update: {
          bank_account_name?: string | null
          bank_account_number?: string | null
          bank_name?: string | null
          gcash_name?: string | null
          gcash_number?: string | null
          landlord_id?: string
          maya_name?: string | null
          maya_number?: string | null
          note?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "landlord_payout_landlord_id_fkey"
            columns: ["landlord_id"]
            isOneToOne: true
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "landlord_payout_landlord_id_fkey"
            columns: ["landlord_id"]
            isOneToOne: true
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      landlord_profiles: {
        Row: {
          avg_response_minutes: number | null
          extracted_gov_id: string | null
          extracted_name: string | null
          government_id_url: string | null
          response_rate: number | null
          user_id: string
        }
        Insert: {
          avg_response_minutes?: number | null
          extracted_gov_id?: string | null
          extracted_name?: string | null
          government_id_url?: string | null
          response_rate?: number | null
          user_id: string
        }
        Update: {
          avg_response_minutes?: number | null
          extracted_gov_id?: string | null
          extracted_name?: string | null
          government_id_url?: string | null
          response_rate?: number | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "landlord_profiles_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "landlord_profiles_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      landlord_reviews: {
        Row: {
          comment: string | null
          created_at: string
          id: string
          landlord_id: string
          lease_id: string
          rating: number
          student_id: string
        }
        Insert: {
          comment?: string | null
          created_at?: string
          id?: string
          landlord_id: string
          lease_id: string
          rating: number
          student_id: string
        }
        Update: {
          comment?: string | null
          created_at?: string
          id?: string
          landlord_id?: string
          lease_id?: string
          rating?: number
          student_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "landlord_reviews_landlord_id_fkey"
            columns: ["landlord_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "landlord_reviews_landlord_id_fkey"
            columns: ["landlord_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "landlord_reviews_lease_id_fkey"
            columns: ["lease_id"]
            isOneToOne: true
            referencedRelation: "leases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "landlord_reviews_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "landlord_reviews_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      leases: {
        Row: {
          added_by_landlord: boolean
          advance_paid: number | null
          allow_partial: boolean
          decision_reason: string | null
          deposit_paid: number | null
          electric_billing:
            | Database["public"]["Enums"]["utility_billing"]
            | null
          electric_flat_fee: number | null
          end_date: string
          ended_reason: string | null
          grace_days: number
          id: string
          landlord_id: string
          leave_requested_at: string | null
          monthly_rent: number | null
          partial_min_pct: number
          rent_due_day: number | null
          room_id: string
          start_date: string
          status: Database["public"]["Enums"]["lease_status"]
          student_id: string
          water_billing: Database["public"]["Enums"]["utility_billing"] | null
          water_flat_fee: number | null
          wifi_billing: Database["public"]["Enums"]["utility_billing"] | null
          wifi_flat_fee: number | null
        }
        Insert: {
          added_by_landlord?: boolean
          advance_paid?: number | null
          allow_partial?: boolean
          decision_reason?: string | null
          deposit_paid?: number | null
          electric_billing?:
            | Database["public"]["Enums"]["utility_billing"]
            | null
          electric_flat_fee?: number | null
          end_date: string
          ended_reason?: string | null
          grace_days?: number
          id?: string
          landlord_id: string
          leave_requested_at?: string | null
          monthly_rent?: number | null
          partial_min_pct?: number
          rent_due_day?: number | null
          room_id: string
          start_date: string
          status?: Database["public"]["Enums"]["lease_status"]
          student_id: string
          water_billing?: Database["public"]["Enums"]["utility_billing"] | null
          water_flat_fee?: number | null
          wifi_billing?: Database["public"]["Enums"]["utility_billing"] | null
          wifi_flat_fee?: number | null
        }
        Update: {
          added_by_landlord?: boolean
          advance_paid?: number | null
          allow_partial?: boolean
          decision_reason?: string | null
          deposit_paid?: number | null
          electric_billing?:
            | Database["public"]["Enums"]["utility_billing"]
            | null
          electric_flat_fee?: number | null
          end_date?: string
          ended_reason?: string | null
          grace_days?: number
          id?: string
          landlord_id?: string
          leave_requested_at?: string | null
          monthly_rent?: number | null
          partial_min_pct?: number
          rent_due_day?: number | null
          room_id?: string
          start_date?: string
          status?: Database["public"]["Enums"]["lease_status"]
          student_id?: string
          water_billing?: Database["public"]["Enums"]["utility_billing"] | null
          water_flat_fee?: number | null
          wifi_billing?: Database["public"]["Enums"]["utility_billing"] | null
          wifi_flat_fee?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "leases_landlord_id_fkey"
            columns: ["landlord_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "leases_landlord_id_fkey"
            columns: ["landlord_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "leases_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "rooms"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "leases_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "leases_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      messages: {
        Row: {
          attachment_url: string | null
          body: string
          conversation_id: string
          id: string
          sender_id: string
          sent_at: string
          status: Database["public"]["Enums"]["msg_status"]
        }
        Insert: {
          attachment_url?: string | null
          body: string
          conversation_id: string
          id?: string
          sender_id: string
          sent_at?: string
          status?: Database["public"]["Enums"]["msg_status"]
        }
        Update: {
          attachment_url?: string | null
          body?: string
          conversation_id?: string
          id?: string
          sender_id?: string
          sent_at?: string
          status?: Database["public"]["Enums"]["msg_status"]
        }
        Relationships: [
          {
            foreignKeyName: "messages_conversation_id_fkey"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "conversations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          body: string
          created_at: string
          id: string
          link_url: string | null
          read_at: string | null
          ref_id: string | null
          source: string | null
          title: string
          type: string
          user_id: string
        }
        Insert: {
          body: string
          created_at?: string
          id?: string
          link_url?: string | null
          read_at?: string | null
          ref_id?: string | null
          source?: string | null
          title: string
          type: string
          user_id: string
        }
        Update: {
          body?: string
          created_at?: string
          id?: string
          link_url?: string | null
          read_at?: string | null
          ref_id?: string | null
          source?: string | null
          title?: string
          type?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      payments: {
        Row: {
          amount: number
          batch_id: string | null
          bill_id: string | null
          claimed_amount: number | null
          created_at: string
          description: string | null
          id: string
          kind: string
          lease_id: string
          method: Database["public"]["Enums"]["payment_method"]
          month: string
          note: string | null
          paid_at: string | null
          promise_date: string | null
          proof_hash: string | null
          proof_url: string | null
          receipt_no: string | null
          rejection_reason: string | null
          status: Database["public"]["Enums"]["payment_status"]
          txn_reference: string | null
          undo_reason: string | null
          verified_by: string | null
        }
        Insert: {
          amount: number
          batch_id?: string | null
          bill_id?: string | null
          claimed_amount?: number | null
          created_at?: string
          description?: string | null
          id?: string
          kind?: string
          lease_id: string
          method: Database["public"]["Enums"]["payment_method"]
          month: string
          note?: string | null
          paid_at?: string | null
          promise_date?: string | null
          proof_hash?: string | null
          proof_url?: string | null
          receipt_no?: string | null
          rejection_reason?: string | null
          status?: Database["public"]["Enums"]["payment_status"]
          txn_reference?: string | null
          undo_reason?: string | null
          verified_by?: string | null
        }
        Update: {
          amount?: number
          batch_id?: string | null
          bill_id?: string | null
          claimed_amount?: number | null
          created_at?: string
          description?: string | null
          id?: string
          kind?: string
          lease_id?: string
          method?: Database["public"]["Enums"]["payment_method"]
          month?: string
          note?: string | null
          paid_at?: string | null
          promise_date?: string | null
          proof_hash?: string | null
          proof_url?: string | null
          receipt_no?: string | null
          rejection_reason?: string | null
          status?: Database["public"]["Enums"]["payment_status"]
          txn_reference?: string | null
          undo_reason?: string | null
          verified_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "payments_bill_id_fkey"
            columns: ["bill_id"]
            isOneToOne: false
            referencedRelation: "utility_bills"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payments_lease_id_fkey"
            columns: ["lease_id"]
            isOneToOne: false
            referencedRelation: "leases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payments_verified_by_fkey"
            columns: ["verified_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payments_verified_by_fkey"
            columns: ["verified_by"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      policies: {
        Row: {
          archived: boolean
          body: string
          created_by: string
          effective_date: string
          id: string
          revision: number
          title: string
          updated_at: string
          version: string | null
        }
        Insert: {
          archived?: boolean
          body: string
          created_by: string
          effective_date: string
          id?: string
          revision?: number
          title: string
          updated_at?: string
          version?: string | null
        }
        Update: {
          archived?: boolean
          body?: string
          created_by?: string
          effective_date?: string
          id?: string
          revision?: number
          title?: string
          updated_at?: string
          version?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "policies_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "policies_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      policy_acceptances: {
        Row: {
          accepted_at: string
          policy_id: string
          revision: number
          user_id: string
        }
        Insert: {
          accepted_at?: string
          policy_id: string
          revision: number
          user_id: string
        }
        Update: {
          accepted_at?: string
          policy_id?: string
          revision?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "policy_acceptances_policy_id_fkey"
            columns: ["policy_id"]
            isOneToOne: false
            referencedRelation: "policies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "policy_acceptances_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "policy_acceptances_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      policy_versions: {
        Row: {
          body: string
          created_by: string | null
          effective_date: string
          id: string
          policy_id: string
          revision: number
          superseded_at: string
          title: string
          version: string | null
        }
        Insert: {
          body: string
          created_by?: string | null
          effective_date: string
          id?: string
          policy_id: string
          revision: number
          superseded_at?: string
          title: string
          version?: string | null
        }
        Update: {
          body?: string
          created_by?: string | null
          effective_date?: string
          id?: string
          policy_id?: string
          revision?: number
          superseded_at?: string
          title?: string
          version?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "policy_versions_policy_id_fkey"
            columns: ["policy_id"]
            isOneToOne: false
            referencedRelation: "policies"
            referencedColumns: ["id"]
          },
        ]
      }
      push_tokens: {
        Row: {
          token: string
          updated_at: string
          user_id: string
        }
        Insert: {
          token: string
          updated_at?: string
          user_id: string
        }
        Update: {
          token?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "push_tokens_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "push_tokens_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      qr_scans: {
        Row: {
          id: string
          method: string
          result: string
          scanned_at: string
          scanner_id: string
          student_id: string | null
        }
        Insert: {
          id?: string
          method?: string
          result: string
          scanned_at?: string
          scanner_id: string
          student_id?: string | null
        }
        Update: {
          id?: string
          method?: string
          result?: string
          scanned_at?: string
          scanner_id?: string
          student_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "qr_scans_scanner_id_fkey"
            columns: ["scanner_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "qr_scans_scanner_id_fkey"
            columns: ["scanner_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "qr_scans_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "qr_scans_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      rate_limit_hits: {
        Row: {
          hits: number
          key: string
          window_start: string
        }
        Insert: {
          hits?: number
          key: string
          window_start: string
        }
        Update: {
          hits?: number
          key?: string
          window_start?: string
        }
        Relationships: []
      }
      report_settings: {
        Row: {
          approved_by_name: string | null
          approved_by_position: string | null
          id: boolean
          noted_by_name: string | null
          noted_by_position: string | null
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          approved_by_name?: string | null
          approved_by_position?: string | null
          id?: boolean
          noted_by_name?: string | null
          noted_by_position?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          approved_by_name?: string | null
          approved_by_position?: string | null
          id?: boolean
          noted_by_name?: string | null
          noted_by_position?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "report_settings_updated_by_fkey"
            columns: ["updated_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "report_settings_updated_by_fkey"
            columns: ["updated_by"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      room_images: {
        Row: {
          id: string
          room_id: string
          sort_order: number | null
          url: string
        }
        Insert: {
          id?: string
          room_id: string
          sort_order?: number | null
          url: string
        }
        Update: {
          id?: string
          room_id?: string
          sort_order?: number | null
          url?: string
        }
        Relationships: [
          {
            foreignKeyName: "room_images_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "rooms"
            referencedColumns: ["id"]
          },
        ]
      }
      rooms: {
        Row: {
          accommodation_id: string
          advance_months: number | null
          capacity: number | null
          current_pax: number | null
          custom_room_type: string | null
          deposit_months: number | null
          electric_billing:
            | Database["public"]["Enums"]["utility_billing"]
            | null
          electric_flat_fee: number | null
          floor: number | null
          id: string
          label: string | null
          monthly_rent: number | null
          rent_basis: string
          room_number: string | null
          room_type: string | null
          status: Database["public"]["Enums"]["room_status"]
          water_billing: Database["public"]["Enums"]["utility_billing"] | null
          water_flat_fee: number | null
          wifi_billing: Database["public"]["Enums"]["utility_billing"] | null
          wifi_flat_fee: number | null
        }
        Insert: {
          accommodation_id: string
          advance_months?: number | null
          capacity?: number | null
          current_pax?: number | null
          custom_room_type?: string | null
          deposit_months?: number | null
          electric_billing?:
            | Database["public"]["Enums"]["utility_billing"]
            | null
          electric_flat_fee?: number | null
          floor?: number | null
          id?: string
          label?: string | null
          monthly_rent?: number | null
          rent_basis?: string
          room_number?: string | null
          room_type?: string | null
          status: Database["public"]["Enums"]["room_status"]
          water_billing?: Database["public"]["Enums"]["utility_billing"] | null
          water_flat_fee?: number | null
          wifi_billing?: Database["public"]["Enums"]["utility_billing"] | null
          wifi_flat_fee?: number | null
        }
        Update: {
          accommodation_id?: string
          advance_months?: number | null
          capacity?: number | null
          current_pax?: number | null
          custom_room_type?: string | null
          deposit_months?: number | null
          electric_billing?:
            | Database["public"]["Enums"]["utility_billing"]
            | null
          electric_flat_fee?: number | null
          floor?: number | null
          id?: string
          label?: string | null
          monthly_rent?: number | null
          rent_basis?: string
          room_number?: string | null
          room_type?: string | null
          status?: Database["public"]["Enums"]["room_status"]
          water_billing?: Database["public"]["Enums"]["utility_billing"] | null
          water_flat_fee?: number | null
          wifi_billing?: Database["public"]["Enums"]["utility_billing"] | null
          wifi_flat_fee?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "rooms_accommodation_id_fkey"
            columns: ["accommodation_id"]
            isOneToOne: false
            referencedRelation: "accommodations"
            referencedColumns: ["id"]
          },
        ]
      }
      sign_in_history: {
        Row: {
          created_at: string
          id: number
          ip: unknown
          session_id: string
          user_agent: string | null
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: never
          ip?: unknown
          session_id: string
          user_agent?: string | null
          user_id: string
        }
        Update: {
          created_at?: string
          id?: never
          ip?: unknown
          session_id?: string
          user_agent?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "sign_in_history_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sign_in_history_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      student_profiles: {
        Row: {
          assessment_of_fees_url: string | null
          college: string | null
          document_text: Json | null
          emergency_contact_json: Json | null
          extracted_name: string | null
          extracted_school_id: string | null
          osas_verified_at: string | null
          program: string | null
          qr_code_token: string | null
          qr_token_expires_at: string | null
          qr_token_rotated_at: string | null
          school_id_url: string | null
          student_id: string | null
          user_id: string
          year_level: number | null
        }
        Insert: {
          assessment_of_fees_url?: string | null
          college?: string | null
          document_text?: Json | null
          emergency_contact_json?: Json | null
          extracted_name?: string | null
          extracted_school_id?: string | null
          osas_verified_at?: string | null
          program?: string | null
          qr_code_token?: string | null
          qr_token_expires_at?: string | null
          qr_token_rotated_at?: string | null
          school_id_url?: string | null
          student_id?: string | null
          user_id: string
          year_level?: number | null
        }
        Update: {
          assessment_of_fees_url?: string | null
          college?: string | null
          document_text?: Json | null
          emergency_contact_json?: Json | null
          extracted_name?: string | null
          extracted_school_id?: string | null
          osas_verified_at?: string | null
          program?: string | null
          qr_code_token?: string | null
          qr_token_expires_at?: string | null
          qr_token_rotated_at?: string | null
          school_id_url?: string | null
          student_id?: string | null
          user_id?: string
          year_level?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "student_profiles_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "student_profiles_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      tenant_reviews: {
        Row: {
          comment: string | null
          created_at: string
          id: string
          landlord_id: string
          lease_id: string
          rating: number
          student_id: string
        }
        Insert: {
          comment?: string | null
          created_at?: string
          id?: string
          landlord_id: string
          lease_id: string
          rating: number
          student_id: string
        }
        Update: {
          comment?: string | null
          created_at?: string
          id?: string
          landlord_id?: string
          lease_id?: string
          rating?: number
          student_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "tenant_reviews_landlord_id_fkey"
            columns: ["landlord_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tenant_reviews_landlord_id_fkey"
            columns: ["landlord_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tenant_reviews_lease_id_fkey"
            columns: ["lease_id"]
            isOneToOne: true
            referencedRelation: "leases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tenant_reviews_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tenant_reviews_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      ticket_messages: {
        Row: {
          attachment_urls: string[]
          author_id: string | null
          author_role: string
          body: string
          created_at: string
          id: string
          is_internal: boolean
          ticket_id: string
        }
        Insert: {
          attachment_urls?: string[]
          author_id?: string | null
          author_role?: string
          body: string
          created_at?: string
          id?: string
          is_internal?: boolean
          ticket_id: string
        }
        Update: {
          attachment_urls?: string[]
          author_id?: string | null
          author_role?: string
          body?: string
          created_at?: string
          id?: string
          is_internal?: boolean
          ticket_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ticket_messages_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ticket_messages_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ticket_messages_ticket_id_fkey"
            columns: ["ticket_id"]
            isOneToOne: false
            referencedRelation: "tickets"
            referencedColumns: ["id"]
          },
        ]
      }
      tickets: {
        Row: {
          accommodation_id: string | null
          assignee_id: string | null
          category: string | null
          concern_id: string | null
          description: string | null
          id: string
          landlord_id: string | null
          lease_id: string | null
          photo_urls: string[]
          priority: string
          reported_at: string
          reporter_name: string | null
          resolved_at: string | null
          status: string
          student_id: string | null
          subject: string | null
          ticket_no: number
          updated_at: string
        }
        Insert: {
          accommodation_id?: string | null
          assignee_id?: string | null
          category?: string | null
          concern_id?: string | null
          description?: string | null
          id?: string
          landlord_id?: string | null
          lease_id?: string | null
          photo_urls?: string[]
          priority?: string
          reported_at?: string
          reporter_name?: string | null
          resolved_at?: string | null
          status?: string
          student_id?: string | null
          subject?: string | null
          ticket_no?: number
          updated_at?: string
        }
        Update: {
          accommodation_id?: string | null
          assignee_id?: string | null
          category?: string | null
          concern_id?: string | null
          description?: string | null
          id?: string
          landlord_id?: string | null
          lease_id?: string | null
          photo_urls?: string[]
          priority?: string
          reported_at?: string
          reporter_name?: string | null
          resolved_at?: string | null
          status?: string
          student_id?: string | null
          subject?: string | null
          ticket_no?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "tickets_accommodation_id_fkey"
            columns: ["accommodation_id"]
            isOneToOne: false
            referencedRelation: "accommodations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tickets_assignee_id_fkey"
            columns: ["assignee_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tickets_assignee_id_fkey"
            columns: ["assignee_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tickets_concern_id_fkey"
            columns: ["concern_id"]
            isOneToOne: true
            referencedRelation: "concerns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tickets_landlord_id_fkey"
            columns: ["landlord_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tickets_landlord_id_fkey"
            columns: ["landlord_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tickets_lease_id_fkey"
            columns: ["lease_id"]
            isOneToOne: false
            referencedRelation: "leases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tickets_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tickets_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      user_pins: {
        Row: {
          attempts: number
          locked_until: string | null
          pin_hash: string
          updated_at: string
          user_id: string
        }
        Insert: {
          attempts?: number
          locked_until?: string | null
          pin_hash: string
          updated_at?: string
          user_id: string
        }
        Update: {
          attempts?: number
          locked_until?: string | null
          pin_hash?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_pins_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_pins_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      users: {
        Row: {
          avatar_color: string | null
          avatar_url: string | null
          closed_at: string | null
          created_at: string | null
          date_of_birth: string | null
          email: string
          email_verified_at: string | null
          full_name: string
          id: string
          initials: string
          is_superadmin: boolean
          last_login_at: string | null
          login_alerts: boolean
          notification_prefs: Json
          onboarding_complete: boolean
          phone: string
          privacy_accepted_at: string | null
          registered_at: string | null
          reviewing_at: string | null
          reviewing_by: string | null
          role: Database["public"]["Enums"]["user_role"]
          sex: string | null
          status: Database["public"]["Enums"]["user_status"]
          terms_accepted_at: string | null
          updated_at: string | null
        }
        Insert: {
          avatar_color?: string | null
          avatar_url?: string | null
          closed_at?: string | null
          created_at?: string | null
          date_of_birth?: string | null
          email: string
          email_verified_at?: string | null
          full_name: string
          id: string
          initials: string
          is_superadmin?: boolean
          last_login_at?: string | null
          login_alerts?: boolean
          notification_prefs?: Json
          onboarding_complete?: boolean
          phone: string
          privacy_accepted_at?: string | null
          registered_at?: string | null
          reviewing_at?: string | null
          reviewing_by?: string | null
          role: Database["public"]["Enums"]["user_role"]
          sex?: string | null
          status?: Database["public"]["Enums"]["user_status"]
          terms_accepted_at?: string | null
          updated_at?: string | null
        }
        Update: {
          avatar_color?: string | null
          avatar_url?: string | null
          closed_at?: string | null
          created_at?: string | null
          date_of_birth?: string | null
          email?: string
          email_verified_at?: string | null
          full_name?: string
          id?: string
          initials?: string
          is_superadmin?: boolean
          last_login_at?: string | null
          login_alerts?: boolean
          notification_prefs?: Json
          onboarding_complete?: boolean
          phone?: string
          privacy_accepted_at?: string | null
          registered_at?: string | null
          reviewing_at?: string | null
          reviewing_by?: string | null
          role?: Database["public"]["Enums"]["user_role"]
          sex?: string | null
          status?: Database["public"]["Enums"]["user_status"]
          terms_accepted_at?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "users_reviewing_by_fkey"
            columns: ["reviewing_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "users_reviewing_by_fkey"
            columns: ["reviewing_by"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      utility_bills: {
        Row: {
          amount: number
          created_at: string
          due_date: string
          id: string
          lease_id: string
          month: string
          note: string | null
          overdue_notified_at: string | null
          reminded_at: string | null
          utility: string
        }
        Insert: {
          amount: number
          created_at?: string
          due_date?: string
          id?: string
          lease_id: string
          month: string
          note?: string | null
          overdue_notified_at?: string | null
          reminded_at?: string | null
          utility: string
        }
        Update: {
          amount?: number
          created_at?: string
          due_date?: string
          id?: string
          lease_id?: string
          month?: string
          note?: string | null
          overdue_notified_at?: string | null
          reminded_at?: string | null
          utility?: string
        }
        Relationships: [
          {
            foreignKeyName: "utility_bills_lease_id_fkey"
            columns: ["lease_id"]
            isOneToOne: false
            referencedRelation: "leases"
            referencedColumns: ["id"]
          },
        ]
      }
      verification_documents: {
        Row: {
          doc_type: string | null
          expires_at: string | null
          file_url: string | null
          filename: string | null
          id: string
          status: Database["public"]["Enums"]["doc_status"]
          uploaded_at: string | null
          user_id: string | null
          verified_at: string | null
          verified_by: string | null
        }
        Insert: {
          doc_type?: string | null
          expires_at?: string | null
          file_url?: string | null
          filename?: string | null
          id?: string
          status?: Database["public"]["Enums"]["doc_status"]
          uploaded_at?: string | null
          user_id?: string | null
          verified_at?: string | null
          verified_by?: string | null
        }
        Update: {
          doc_type?: string | null
          expires_at?: string | null
          file_url?: string | null
          filename?: string | null
          id?: string
          status?: Database["public"]["Enums"]["doc_status"]
          uploaded_at?: string | null
          user_id?: string | null
          verified_at?: string | null
          verified_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "verification_documents_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "verification_documents_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "verification_documents_verified_by_fkey"
            columns: ["verified_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "verification_documents_verified_by_fkey"
            columns: ["verified_by"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
      verification_requests: {
        Row: {
          created_at: string
          decision_notes: string | null
          entity_id: string
          entity_type: string
          id: string
          rejection_reasons: string[] | null
          reviewed_at: string
          reviewed_by: string | null
          status: string
          type: string | null
        }
        Insert: {
          created_at?: string
          decision_notes?: string | null
          entity_id: string
          entity_type: string
          id?: string
          rejection_reasons?: string[] | null
          reviewed_at?: string
          reviewed_by?: string | null
          status: string
          type?: string | null
        }
        Update: {
          created_at?: string
          decision_notes?: string | null
          entity_id?: string
          entity_type?: string
          id?: string
          rejection_reasons?: string[] | null
          reviewed_at?: string
          reviewed_by?: string | null
          status?: string
          type?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "verification_requests_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "verification_requests_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      latest_accommodation_documents: {
        Row: {
          accommodation_id: string | null
          doc_type: string | null
          expires_at: string | null
          file_url: string | null
          issued_at: string | null
          uploaded_at: string | null
          version: number | null
        }
        Relationships: [
          {
            foreignKeyName: "accommodation_documents_accommodation_id_fkey"
            columns: ["accommodation_id"]
            isOneToOne: false
            referencedRelation: "accommodations"
            referencedColumns: ["id"]
          },
        ]
      }
      review_admin_feed: {
        Row: {
          accommodation_id: string | null
          author_id: string | null
          comment: string | null
          created_at: string | null
          id: string | null
          kind: string | null
          lease_id: string | null
          rating: number | null
          subject_id: string | null
        }
        Relationships: []
      }
      review_inbox: {
        Row: {
          accommodation_id: string | null
          accommodation_name: string | null
          comment: string | null
          created_at: string | null
          id: string | null
          kind: string | null
          rating: number | null
        }
        Relationships: []
      }
      review_written_leases: {
        Row: {
          comment: string | null
          kind: string | null
          lease_id: string | null
          rating: number | null
        }
        Relationships: []
      }
      users_full: {
        Row: {
          avatar_color: string | null
          avatar_url: string | null
          closed_at: string | null
          created_at: string | null
          date_of_birth: string | null
          email: string | null
          email_verified_at: string | null
          full_name: string | null
          id: string | null
          initials: string | null
          is_superadmin: boolean | null
          last_login_at: string | null
          login_alerts: boolean | null
          notification_prefs: Json | null
          onboarding_complete: boolean | null
          phone: string | null
          privacy_accepted_at: string | null
          registered_at: string | null
          reviewing_at: string | null
          reviewing_by: string | null
          role: Database["public"]["Enums"]["user_role"] | null
          sex: string | null
          status: Database["public"]["Enums"]["user_status"] | null
          terms_accepted_at: string | null
          updated_at: string | null
        }
        Insert: {
          avatar_color?: string | null
          avatar_url?: string | null
          closed_at?: string | null
          created_at?: string | null
          date_of_birth?: never
          email?: string | null
          email_verified_at?: string | null
          full_name?: string | null
          id?: string | null
          initials?: string | null
          is_superadmin?: boolean | null
          last_login_at?: string | null
          login_alerts?: boolean | null
          notification_prefs?: Json | null
          onboarding_complete?: boolean | null
          phone?: string | null
          privacy_accepted_at?: string | null
          registered_at?: string | null
          reviewing_at?: string | null
          reviewing_by?: string | null
          role?: Database["public"]["Enums"]["user_role"] | null
          sex?: string | null
          status?: Database["public"]["Enums"]["user_status"] | null
          terms_accepted_at?: string | null
          updated_at?: string | null
        }
        Update: {
          avatar_color?: string | null
          avatar_url?: string | null
          closed_at?: string | null
          created_at?: string | null
          date_of_birth?: never
          email?: string | null
          email_verified_at?: string | null
          full_name?: string | null
          id?: string | null
          initials?: string | null
          is_superadmin?: boolean | null
          last_login_at?: string | null
          login_alerts?: boolean | null
          notification_prefs?: Json | null
          onboarding_complete?: boolean | null
          phone?: string | null
          privacy_accepted_at?: string | null
          registered_at?: string | null
          reviewing_at?: string | null
          reviewing_by?: string | null
          role?: Database["public"]["Enums"]["user_role"] | null
          sex?: string | null
          status?: Database["public"]["Enums"]["user_status"] | null
          terms_accepted_at?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "users_reviewing_by_fkey"
            columns: ["reviewing_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "users_reviewing_by_fkey"
            columns: ["reviewing_by"]
            isOneToOne: false
            referencedRelation: "users_full"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      accept_added_student: {
        Args: { p_code: string; p_lease: string }
        Returns: undefined
      }
      accept_policy: { Args: { p_id: string }; Returns: undefined }
      accommodation_missing: { Args: { p_id: string }; Returns: string[] }
      accreditation_term: { Args: never; Returns: string }
      accreditation_wait_estimate: { Args: never; Returns: number }
      add_student_to_room: {
        Args: { p_room: string; p_start: string; p_student_no: string }
        Returns: string
      }
      admin_change_role: {
        Args: {
          p_reason: string
          p_role: Database["public"]["Enums"]["user_role"]
          p_user: string
        }
        Returns: undefined
      }
      admin_close_account: {
        Args: { p_reason: string; p_user: string }
        Returns: undefined
      }
      admin_disconnect_google: { Args: { p_user: string }; Returns: undefined }
      admin_expired: { Args: { p_uid: string }; Returns: boolean }
      admin_level: { Args: { p_area: string }; Returns: string }
      admin_levels_valid: { Args: { p: Json }; Returns: boolean }
      admin_set_account_status: {
        Args: {
          p_docs?: string[]
          p_reason?: string
          p_restrictions?: string[]
          p_status: Database["public"]["Enums"]["user_status"]
          p_until?: string
          p_user: string
        }
        Returns: undefined
      }
      admin_sign_in_methods: {
        Args: { p_user: string }
        Returns: {
          has_google: boolean
          has_password: boolean
          last_sign_in_at: string
        }[]
      }
      admin_sign_out_everywhere: { Args: { p_user: string }; Returns: number }
      announce_due: { Args: never; Returns: number }
      announcement_reach: {
        Args: { p_id: string }
        Returns: {
          seen: number
          sent: number
        }[]
      }
      announcement_reach_all: {
        Args: never
        Returns: {
          announcement_id: string
          seen: number
          sent: number
        }[]
      }
      appeal_accommodation: {
        Args: { p_id: string; p_message: string }
        Returns: undefined
      }
      archive_expired_announcements: { Args: never; Returns: number }
      assert_admin_over: { Args: { p_user: string }; Returns: undefined }
      audit_entry: { Args: { p_id: string }; Returns: Json }
      audit_json: {
        Args: { a: Database["public"]["Tables"]["audit_logs"]["Row"] }
        Returns: Json
      }
      audit_visible: { Args: { p_type: string }; Returns: boolean }
      can_edit: { Args: { p_area: string }; Returns: boolean }
      can_notify: { Args: { target: string }; Returns: boolean }
      can_view: { Args: { p_area: string }; Returns: boolean }
      check_session: { Args: never; Returns: undefined }
      check_student_id_exists: {
        Args: { p_student_id: string }
        Returns: boolean
      }
      clear_pin: { Args: { p_current: string }; Returns: boolean }
      complete_registration: { Args: never; Returns: undefined }
      confirm_email_ownership: { Args: never; Returns: boolean }
      current_is_superadmin: { Args: never; Returns: boolean }
      current_qr_token: {
        Args: never
        Returns: {
          expires_at: string
          token: string
        }[]
      }
      decide_accreditation: {
        Args: {
          p_accommodation: string
          p_decision: string
          p_flagged_docs?: string[]
          p_note?: string
          p_override?: boolean
          p_tags?: string[]
        }
        Returns: string
      }
      fanout_announcement: { Args: { p_id: string }; Returns: number }
      get_my_role: { Args: never; Returns: string }
      get_verification_queue: {
        Args: never
        Returns: {
          avatar_url: string
          created_at: string
          doc_id: string
          doc_status: string
          doc_type: string
          email: string
          file_url: string
          filename: string
          full_name: string
          reviewing_at: string
          reviewing_by: string
          role: string
          user_id: string
          user_status: string
        }[]
      }
      has_pin: { Args: never; Returns: boolean }
      initials_from_name: { Args: { p_name: string }; Returns: string }
      invite_application: {
        Args: { p_conversation: string }
        Returns: undefined
      }
      is_accredited_accommodation: { Args: { p_id: string }; Returns: boolean }
      is_admin: { Args: { p_uid: string }; Returns: boolean }
      is_verified_landlord: { Args: { uid: string }; Returns: boolean }
      landlord_title: { Args: { p_user: string }; Returns: string }
      lease_ledger: {
        Args: { p_lease: string }
        Returns: {
          balance: number
          bill_id: string
          confirmed: number
          due: number
          due_date: string
          kind: string
          month: string
          pending: number
          state: string
          waived: number
        }[]
      }
      ledger_rows: {
        Args: { p_lease: string }
        Returns: {
          balance: number
          bill_id: string
          confirmed: number
          due: number
          due_date: string
          kind: string
          month: string
          pending: number
          state: string
          waived: number
        }[]
      }
      lift_expired_suspensions: { Args: never; Returns: number }
      mark_conversation_read: {
        Args: { p_conversation: string }
        Returns: undefined
      }
      may_message: { Args: { p_other: string }; Returns: boolean }
      mfa_ok: { Args: { p_uid: string }; Returns: boolean }
      my_accommodation_ids: {
        Args: never
        Returns: {
          id: string
        }[]
      }
      my_sign_ins: {
        Args: never
        Returns: {
          active: boolean
          current: boolean
          ip: string
          last_active_at: string
          session_id: string
          signed_in_at: string
          user_agent: string
        }[]
      }
      notify_admins: {
        Args: {
          p_body: string
          p_link_url: string
          p_title: string
          p_type: string
        }
        Returns: undefined
      }
      notify_peer: {
        Args: {
          p_body: string
          p_from: string
          p_link: string
          p_title: string
          p_type: string
          p_user: string
        }
        Returns: undefined
      }
      notify_system: {
        Args: {
          p_body: string
          p_link: string
          p_title: string
          p_type: string
          p_user: string
        }
        Returns: undefined
      }
      open_accreditation_round: {
        Args: {
          p_changes?: Json
          p_id: string
          p_kind: string
          p_message?: string
        }
        Returns: string
      }
      past_stay_balance: { Args: { p_student: string }; Returns: number }
      payment_covered: {
        Args: {
          p_bill: string
          p_except: string
          p_kind: string
          p_lease: string
          p_month: string
        }
        Returns: Record<string, unknown>
      }
      payment_due: {
        Args: {
          p_bill?: string
          p_kind: string
          p_lease: string
          p_month: string
        }
        Returns: number
      }
      permit_label: { Args: { p_type: string }; Returns: string }
      permit_replacement_open: {
        Args: { p_acc: string; p_doc: string }
        Returns: boolean
      }
      peso: { Args: { p: number }; Returns: string }
      pin_attempt: { Args: { p_pin: string }; Returns: boolean }
      policy_acceptance_stats: {
        Args: never
        Returns: {
          accepted: number
          eligible: number
          policy_id: string
        }[]
      }
      policy_pending_users: {
        Args: { p_id: string }
        Returns: {
          email: string
          full_name: string
          id: string
          role: string
        }[]
      }
      purge_rate_limit_hits: { Args: never; Returns: undefined }
      purge_unverified_accounts: {
        Args: { p_older_than?: string }
        Returns: number
      }
      rate_limit_hit: {
        Args: { p_key: string; p_max: number; p_window: number }
        Returns: boolean
      }
      reap_unverified_signups: {
        Args: { p_older_than?: string }
        Returns: number
      }
      recompute_room_occupancy: {
        Args: { p_room_id: string }
        Returns: undefined
      }
      record_activity: {
        Args: { p_entity: string; p_limit?: number; p_types: string[] }
        Returns: Json[]
      }
      record_consent: { Args: { p_documents: string[] }; Returns: undefined }
      record_payment: {
        Args: {
          p_amount: number
          p_bill?: string
          p_kind: string
          p_lease: string
          p_method: string
          p_note?: string
          p_promise_date?: string
          p_proof_hash?: string
          p_proof_url?: string
          p_reference?: string
        }
        Returns: string
      }
      record_payments: {
        Args: {
          p_advance: boolean
          p_amount?: number
          p_bills: string[]
          p_deposit: boolean
          p_lease: string
          p_method: string
          p_months: number
          p_note?: string
          p_promise_date?: string
          p_proof_hash?: string
          p_proof_url?: string
          p_reference?: string
        }
        Returns: string
      }
      register_push_token: { Args: { p_token: string }; Returns: undefined }
      remind_accreditation_expiry: { Args: never; Returns: undefined }
      remind_stale_drafts: { Args: never; Returns: undefined }
      remind_utility_bills: { Args: never; Returns: undefined }
      rent_due_date: {
        Args: { p_due_day: number; p_month: string; p_start: string }
        Returns: string
      }
      request_details_change: {
        Args: { p_changes: Json; p_id: string; p_message?: string }
        Returns: undefined
      }
      request_renewal: { Args: { p_id: string }; Returns: undefined }
      resubmit_accommodation: {
        Args: { p_id: string; p_message?: string }
        Returns: number
      }
      resubmit_verification: { Args: never; Returns: undefined }
      review_payment: {
        Args: {
          p_action: string
          p_payment: string
          p_reason?: string
          p_received?: number
        }
        Returns: undefined
      }
      room_display: { Args: { p_room: string }; Returns: string }
      rotate_qr_token: { Args: never; Returns: string }
      send_push: {
        Args: { p_payload: Json; p_user: string }
        Returns: undefined
      }
      set_audit_context: {
        Args: { p_ip_address?: string; p_user_agent?: string }
        Returns: undefined
      }
      set_pin: { Args: { p_pin: string }; Returns: boolean }
      sign_out_session: { Args: { p_session: string }; Returns: boolean }
      student_may_lease: { Args: { p_student: string }; Returns: boolean }
      student_past_balance: {
        Args: { p_student: string }
        Returns: {
          accommodation: string
          balance: number
          ended_on: string
          lease_id: string
          room: string
        }[]
      }
      submit_accommodation: { Args: { p_id: string }; Returns: undefined }
      submit_student_review: {
        Args: {
          p_acc_comment: string
          p_acc_rating: number
          p_accommodation_id: string
          p_landlord_id: string
          p_lease_id: string
          p_manager_comment: string
          p_manager_rating: number
        }
        Returns: undefined
      }
      sweep_expired_accreditations: { Args: never; Returns: undefined }
      sweep_expired_permits: { Args: never; Returns: undefined }
      sync_accommodation_totals: { Args: { p_id: string }; Returns: undefined }
      touch_last_active: { Args: never; Returns: undefined }
      verify_pin: { Args: { p_pin: string }; Returns: boolean }
      verify_student_qr: { Args: { p_code: string }; Returns: Json }
      waive_balance: {
        Args: {
          p_bill: string
          p_kind: string
          p_lease: string
          p_month: string
          p_reason: string
        }
        Returns: undefined
      }
      withdraw_details_change: { Args: { p_id: string }; Returns: undefined }
    }
    Enums: {
      accommodation_status:
        | "pending"
        | "reviewing"
        | "accredited"
        | "rejected"
        | "delisted"
        | "expired"
        | "suspended"
        | "needs_revision"
        | "draft"
      amenity:
        | "wifi"
        | "water"
        | "electric"
        | "aircon"
        | "parking"
        | "kitchen"
        | "laundry"
        | "cctv"
        | "water_dispenser"
        | "generator"
        | "fire_extinguisher"
      audience_type: "all" | "students" | "landlords"
      doc_status: "pending" | "approved" | "rejected"
      lease_status:
        | "active"
        | "ended"
        | "terminated"
        | "leave_requested"
        | "pending"
        | "rejected"
      msg_status: "sent" | "delivered" | "read"
      office: "osas" | "registrar" | "housing"
      payment_method: "gcash" | "maya" | "bank" | "cash" | "others"
      payment_status:
        | "due"
        | "paid"
        | "overdue"
        | "pending_verification"
        | "rejected"
        | "withdrawn"
        | "waived"
      room_status: "available" | "occupied" | "maintenance"
      room_type: "solo" | "duo" | "triple" | "bedspace" | "studio"
      user_role: "student" | "landlord" | "admin"
      user_status:
        | "unverified"
        | "pending"
        | "reviewing"
        | "verified"
        | "needs_resubmission"
        | "rejected"
        | "suspended"
      utility_billing:
        | "included"
        | "own_meter"
        | "split"
        | "flat_fee"
        | "not_available"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      accommodation_status: [
        "pending",
        "reviewing",
        "accredited",
        "rejected",
        "delisted",
        "expired",
        "suspended",
        "needs_revision",
        "draft",
      ],
      amenity: [
        "wifi",
        "water",
        "electric",
        "aircon",
        "parking",
        "kitchen",
        "laundry",
        "cctv",
        "water_dispenser",
        "generator",
        "fire_extinguisher",
      ],
      audience_type: ["all", "students", "landlords"],
      doc_status: ["pending", "approved", "rejected"],
      lease_status: [
        "active",
        "ended",
        "terminated",
        "leave_requested",
        "pending",
        "rejected",
      ],
      msg_status: ["sent", "delivered", "read"],
      office: ["osas", "registrar", "housing"],
      payment_method: ["gcash", "maya", "bank", "cash", "others"],
      payment_status: [
        "due",
        "paid",
        "overdue",
        "pending_verification",
        "rejected",
        "withdrawn",
        "waived",
      ],
      room_status: ["available", "occupied", "maintenance"],
      room_type: ["solo", "duo", "triple", "bedspace", "studio"],
      user_role: ["student", "landlord", "admin"],
      user_status: [
        "unverified",
        "pending",
        "reviewing",
        "verified",
        "needs_resubmission",
        "rejected",
        "suspended",
      ],
      utility_billing: [
        "included",
        "own_meter",
        "split",
        "flat_fee",
        "not_available",
      ],
    },
  },
} as const
