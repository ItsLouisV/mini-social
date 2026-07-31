export interface TableMapItem {
  table: string;
  idColumn: string;
  userColumn: string;
}

export const TABLE_MAP: Record<string, TableMapItem> = {
  post: { table: "posts", idColumn: "post_id", userColumn: "user_id" },
  comment: { table: "comments", idColumn: "comment_id", userColumn: "user_id" },
  message: { table: "messages", idColumn: "message_id", userColumn: "sender_id" },
};

export function isValidContentType(type: string): type is keyof typeof TABLE_MAP {
  return type in TABLE_MAP;
}
