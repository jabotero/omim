#pragma once
#include "indexer/tesselator_decl.hpp"

#include "geometry/point2d.hpp"

#include "std/function.hpp"
#include "std/iterator.hpp"
#include "std/list.hpp"
#include "std/vector.hpp"
#include "std/unordered_map.hpp"
#include "std/utility.hpp"


namespace tesselator
{
  typedef vector<m2::PointD> PointsT;
  typedef list<PointsT> PolygonsT;

  struct Triangle
  {
    int m_p[3];

    Triangle(int p0, int p1, int p2)
    {
      m_p[0] = p0;
      m_p[1] = p1;
      m_p[2] = p2;
    }

    Triangle(int const * p)
    {
      for (int i = 0; i < 3; ++i)
        m_p[i] = p[i];
    }

    int GetPoint3(pair<int, int> const & p) const
    {
      for (int i = 0; i < 3; ++i)
        if (m_p[i] != p.first && m_p[i] != p.second)
          return m_p[i];

      ASSERT ( false, ("Triangle with equal points") );
      return -1;
    }
  };

  // Converted points, prepared for serialization.
  struct PointsInfo
  {
    typedef m2::PointU PointT;
    vector<PointT> m_points;
    PointT m_base, m_max;
  };

  class TrianglesInfo
  {
    PointsT m_points;

    class ListInfo
    {
      static int empty_key;

      vector<Triangle> m_triangles;

      mutable vector<bool> m_visited;

      // directed edge -> triangle
      template <typename T1, typename T2> struct HashPair
      {
        size_t operator()(pair<T1, T2> const & p) const
        {
          return my::Hash(p.first, p.second);
        }
      };

      using TNeighbours = unordered_map<pair<int, int>, int, HashPair<int, int>>;
      TNeighbours m_neighbors;

      void AddNeighbour(int p1, int p2, int trg);

      void GetNeighbors(
          Triangle const & trg, Triangle const & from, int * nb) const;

      uint64_t CalcDelta(
          PointsInfo const & points, Triangle const & from, Triangle const & to) const;

    public:
      using TIterator = TNeighbours::const_iterator;

      ListInfo(size_t count)
      {
        m_triangles.reserve(count);
      }

      void Add(int p0, int p1, int p2);

      void Start() const
      {
        m_visited.resize(m_triangles.size());
      }

      bool HasUnvisited() const
      {
        vector<bool> test;
        test.assign(m_triangles.size(), true);
        return (m_visited != test);
      }

      TIterator FindStartTriangle(PointsInfo const & points) const;

    private:
      template <class TPopOrder>
      void MakeTrianglesChainImpl(PointsInfo const & points, TIterator start, vector<Edge> & chain) const;
    public:
      void MakeTrianglesChain(PointsInfo const & points, TIterator start, vector<Edge> & chain, bool goodOrder) const;

      size_t GetCount() const { return m_triangles.size(); }
      Triangle GetTriangle(size_t i) const { return m_triangles[i]; }
    };

    list<ListInfo> m_triangles;

//    int m_isCCW;  // 0 - uninitialized; -1 - false; 1 - true

  public:
    TrianglesInfo()// : m_isCCW(0)
    {}

    /// @name Making functions.
    template <class IterT> void AssignPoints(IterT b, IterT e)
    {
      m_points.assign(b, e);
    }

    void Reserve(size_t count) { m_triangles.push_back(ListInfo(count)); }

    void Add(int p0, int p1, int p2);
    //@}

    inline bool IsEmpty() const { return m_triangles.empty(); }

    template <class ToDo> void ForEachTriangle(ToDo toDo) const
    {
      for (list<ListInfo>::const_iterator i = m_triangles.begin(); i != m_triangles.end(); ++i)
      {
        size_t const count = i->GetCount();
        for (size_t j = 0; j < count; ++j)
        {
          Triangle const t = i->GetTriangle(j);
          toDo(m_points[t.m_p[0]], m_points[t.m_p[1]], m_points[t.m_p[2]]);
        }
      }
    }

    // Convert points from double to uint.
    void GetPointsInfo(m2::PointU const & baseP, m2::PointU const & maxP,
                       function<m2::PointU (m2::PointD)> const & convert, PointsInfo & info) const;

    /// Triangles chains processing function.
    template <class EmitterT>
    void ProcessPortions(PointsInfo const & points, EmitterT & emitter, bool goodOrder = true) const
    {
      // process portions and push out result chains
      vector<Edge> chain;
      for (list<ListInfo>::const_iterator i = m_triangles.begin(); i != m_triangles.end(); ++i)
      {
        i->Start();

        do
        {
          typename ListInfo::TIterator start = i->FindStartTriangle(points);
          i->MakeTrianglesChain(points, start, chain, goodOrder);

          m2::PointU arr[] = { points.m_points[start->first.first],
                               points.m_points[start->first.second],
                               points.m_points[i->GetTriangle(start->second).GetPoint3(start->first)] };

          emitter(arr, chain);
        } while (i->HasUnvisited());
      }
    }
  };

  /// Main tesselate function.
  /// @returns number of resulting triangles after triangulation.
  int TesselateInterior(PolygonsT const & polys, TrianglesInfo & info);
}
