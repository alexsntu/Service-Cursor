#!/usr/bin/env node

/**
 * PixelPlus MCP Server
 * Provides tools to manage semantic core in PixelPlus SEO projects
 *
 * @file src/pixelplus.js
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ErrorCode,
  ListToolsRequestSchema,
  McpError,
} from '@modelcontextprotocol/sdk/types.js';
import axios from 'axios';

class PixelPlusMCPServer {
  constructor() {
    this.server = new Server(
      {
        name: 'pixelplus-mcp-server',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupToolHandlers();
  }

  setupToolHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      return {
        tools: [
          {
            name: 'pixelplus_get_project',
            description: 'Get info about a PixelPlus SEO project (domain, status)',
            inputSchema: {
              type: 'object',
              properties: {
                project_id: {
                  type: 'number',
                  description: 'PixelPlus project ID (visible in project URL)',
                },
              },
              required: ['project_id'],
            },
          },
          {
            name: 'pixelplus_get_groups',
            description: 'Get list of query groups in a PixelPlus SEO project',
            inputSchema: {
              type: 'object',
              properties: {
                project_id: {
                  type: 'number',
                  description: 'PixelPlus project ID',
                },
              },
              required: ['project_id'],
            },
          },
          {
            name: 'pixelplus_get_queries',
            description: 'Get search queries of a PixelPlus SEO project. Returns all queries by default, or only queries from a specific group if group_id is provided.',
            inputSchema: {
              type: 'object',
              properties: {
                project_id: {
                  type: 'number',
                  description: 'PixelPlus project ID',
                },
                group_id: {
                  type: 'number',
                  description: 'Filter by group ID (optional). Use pixelplus_get_groups to find group IDs.',
                },
              },
              required: ['project_id'],
            },
          },
          {
            name: 'pixelplus_add_queries',
            description: 'Add search queries to a PixelPlus SEO project with group assignment and target URL',
            inputSchema: {
              type: 'object',
              properties: {
                project_id: {
                  type: 'number',
                  description: 'PixelPlus project ID',
                },
                queries: {
                  type: 'array',
                  items: { type: 'string' },
                  description: 'List of search queries to add',
                },
                group: {
                  type: 'string',
                  description: 'Group name to assign the queries to',
                },
                url: {
                  type: 'string',
                  description: 'Target (promoted) URL for these queries',
                },
              },
              required: ['project_id', 'queries', 'group', 'url'],
            },
          },
          {
            name: 'pixelplus_get_updates',
            description: 'Get list of position check updates for a PixelPlus SEO project (each update has an ID and date)',
            inputSchema: {
              type: 'object',
              properties: {
                project_id: {
                  type: 'number',
                  description: 'PixelPlus project ID',
                },
              },
              required: ['project_id'],
            },
          },
          {
            name: 'pixelplus_get_positions',
            description: 'Get positions for a PixelPlus SEO project. Each result includes rel_url (promoted URL), query, position, region. Optionally filter by promoted URL or group. Automatically uses the latest update if update_id is not provided.',
            inputSchema: {
              type: 'object',
              properties: {
                project_id: {
                  type: 'number',
                  description: 'PixelPlus project ID',
                },
                update_id: {
                  type: 'number',
                  description: 'Position update ID (optional — uses latest update if omitted)',
                },
                group_id: {
                  type: 'number',
                  description: 'Filter by group ID (optional)',
                },
                url: {
                  type: 'string',
                  description: 'Filter results by promoted URL (rel_url), e.g. "https://goodmi.ru/noutbuki/noutbuki-dlja-ucheby/" (optional)',
                },
                limit: {
                  type: 'number',
                  description: 'Max number of results to return (optional, default 1000)',
                },
              },
              required: ['project_id'],
            },
          },
        ],
      };
    });

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'pixelplus_get_project':
            return await this.getProject(args);
          case 'pixelplus_get_groups':
            return await this.getGroups(args);
          case 'pixelplus_get_queries':
            return await this.getQueries(args);
          case 'pixelplus_add_queries':
            return await this.addQueries(args);
          case 'pixelplus_get_updates':
            return await this.getUpdates(args);
          case 'pixelplus_get_positions':
            return await this.getPositions(args);
          default:
            throw new McpError(ErrorCode.MethodNotFound, `Unknown tool: ${name}`);
        }
      } catch (error) {
        throw new McpError(ErrorCode.InternalError, `Error executing ${name}: ${error.message}`);
      }
    });
  }

  async makeRequest(group, method, params = {}) {
    const token = process.env.PIXELPLUS_API_TOKEN;
    if (!token) {
      throw new Error('PIXELPLUS_API_TOKEN is not set in environment variables');
    }
    const searchParams = new URLSearchParams({ token, ...params });
    const url = `https://tools.pixelplus.ru/projects/api/v1/${group}/${method}?${searchParams}`;
    const response = await axios.get(url);
    return response.data;
  }

  async getProject(args) {
    const result = await this.makeRequest('project', 'get', {
      project_id: args.project_id,
    });
    return { content: [{ type: 'text', text: JSON.stringify(result, null, 2) }] };
  }

  async getGroups(args) {
    const result = await this.makeRequest('groups', 'get', {
      project_id: args.project_id,
    });
    return { content: [{ type: 'text', text: JSON.stringify(result, null, 2) }] };
  }

  async getQueries(args) {
    const result = await this.makeRequest('queries', 'get', {
      project_id: args.project_id,
    });

    const filtered = args.group_id
      ? result.filter(q => String(q.group_id) === String(args.group_id))
      : result;

    return { content: [{ type: 'text', text: JSON.stringify(filtered, null, 2) }] };
  }

  async addQueries(args) {
    const result = await this.makeRequest('queries', 'set', {
      project_id: args.project_id,
      queries: args.queries.join('|'),
      group: args.group,
      url: args.url,
    });
    return { content: [{ type: 'text', text: JSON.stringify(result, null, 2) }] };
  }

  async getUpdates(args) {
    const result = await this.makeRequest('updates', 'get', {
      project_id: args.project_id,
    });
    return { content: [{ type: 'text', text: JSON.stringify(result, null, 2) }] };
  }

  async getPositions(args) {
    let updateId = args.update_id;

    // Auto-fetch latest update_id if not provided
    if (!updateId) {
      const updates = await this.makeRequest('updates', 'get', {
        project_id: args.project_id,
      });
      if (!updates || updates.length === 0) {
        throw new Error('No position updates found for this project');
      }
      updateId = updates[0].id;
    }

    const params = {
      project_id: args.project_id,
      update_id: updateId,
      limit: args.limit || 1000,
    };
    if (args.group_id) params.group_id = args.group_id;

    let result = await this.makeRequest('positions', 'get', params);

    // Filter by promoted URL if provided
    if (args.url && Array.isArray(result)) {
      result = result.filter(item => item.rel_url === args.url);
    }

    const meta = {
      update_id: updateId,
      total: Array.isArray(result) ? result.length : null,
      filtered_by_url: args.url || null,
    };

    return {
      content: [{
        type: 'text',
        text: JSON.stringify({ meta, positions: result }, null, 2),
      }],
    };
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('PixelPlus MCP server running on stdio');
  }
}

const server = new PixelPlusMCPServer();
server.run().catch(console.error);
